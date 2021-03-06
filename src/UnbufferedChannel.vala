/* UnbufferedChannel.vala
 *
 * Copyright (C) 2019-2020  Космическое П. (kosmospredanie@yandex.ru)
 *
 * This file is part of Gpseq.
 *
 * Gpseq is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Gpseq is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Gpseq.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gpseq {
	/**
	 * Symmetric rendezvous channel implementation using mutexes
	 */
	internal class UnbufferedChannel<G> : Object, ChannelBase, Sender<G>,
			Gee.Traversable<G>, Receiver<G>, Channel<G> {
		private System<G> _system;

		public UnbufferedChannel () {
			_system = new System<G>();
		}

		~UnbufferedChannel () {
			close();
		}

		public Optional<int64?> capacity {
			owned get {
				return new Optional<int64?>.of(0);
			}
		}

		public int64 length {
			get {
				return 0;
			}
		}

		public bool is_full {
			get {
				return true;
			}
		}

		public bool is_empty {
			get {
				return true;
			}
		}

		public void close () {
			_system.close();
		}

		public Result<void*> send (owned G data) {
			Code code = _system.transfer(true, (owned)data, false, false, 0, null);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<void*>(null);
			case Code.CLOSED:
				return Result.err<void*>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public Result<void*> send_until (owned G data, int64 end_time) {
			Code code = _system.transfer(true, (owned)data, false, true, end_time, null);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<void*>(null);
			case Code.FAILED:
				return Result.err<void*>(new ChannelError.TIMEOUT("Sending data timeout"));
			case Code.CLOSED:
				return Result.err<void*>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public Result<void*> try_send (owned G data) {
			Node<G>? node;
			Code code = _system.reserve(true, (owned)data, false, false, 0, null, out node);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<void*>(null);
			case Code.CLOSED:
				return Result.err<void*>(new ChannelError.CLOSED("Channel closed"));
			case Code.CONTINUE:
				break;
			default:
				assert_not_reached();
			}

			code = _system.cancel((!)node, null);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<void*>(null);
			case Code.FAILED:
				return Result.err<void*>(new ChannelError.TRY_FAILED("No receives"));
			case Code.CLOSED:
				return Result.err<void*>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public Result<G> recv () {
			G? res;
			Code code = _system.transfer(false, null, false, false, 0, out res);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<G>((owned) res);
			case Code.CLOSED:
				return Result.err<G>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public Result<G> recv_until (int64 end_time) {
			G? res;
			Code code = _system.transfer(false, null, false, true, end_time, out res);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<G>((owned) res);
			case Code.FAILED:
				return Result.err<G>(new ChannelError.TIMEOUT("Receiving data timeout"));
			case Code.CLOSED:
				return Result.err<G>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public Result<G> try_recv () {
			G? res;
			Node<G>? node;
			Code code = _system.reserve(false, null, false, false, 0, out res, out node);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<G>(null);
			case Code.CLOSED:
				return Result.err<G>(new ChannelError.CLOSED("Channel closed"));
			case Code.CONTINUE:
				break;
			default:
				assert_not_reached();
			}

			code = _system.cancel((!)node, out res);
			switch (code) {
			case Code.SUCCESS:
				return Result.of<G>((owned)res);
			case Code.FAILED:
				return Result.err<G>(new ChannelError.TRY_FAILED("No sends"));
			case Code.CLOSED:
				return Result.err<G>(new ChannelError.CLOSED("Channel closed"));
			default:
				assert_not_reached();
			}
		}

		public bool @foreach (Gee.ForallFunc<G> f) {
			while (true) {
				Result<G> result = recv();
				if (result.exception != null) {
					return true;
				} else if ( !f(result.value) ) {
					return false;
				}
			}
		}

		private enum Code {
			SUCCESS,
			FAILED,
			CLOSED,
			CONTINUE
		}

		private class System<G> : Object {
			private Gee.Queue<Node<G>> _queue;
			private bool _is_data;
			private AtomicBoolVal _closed;
			private Mutex _mutex;

			public System () {
				_queue = new Gee.LinkedList<Node<G>>();
				_closed = new AtomicBoolVal();
				_mutex = Mutex();
			}

			public void close () {
				if (_closed._val == AtomicBoolVal.TRUE) return; // fast-path
				_mutex.lock();
				if ( _closed.compare_and_exchange(false, true) ) {
					while (!_queue.is_empty) {
						Node<G> node = _queue.poll();
						node.mutex.lock();
						node.cond.broadcast();
						node.mutex.unlock();
					}
				}
				_mutex.unlock();
			}

			public Code reserve (bool is_data, owned G? val,
					bool is_try, bool timed, int64 end_time,
					out G? result, out Node<G>? node) {
				if (_closed._val == AtomicBoolVal.TRUE) { // fast-path
					result = null;
					node = null;
					return Code.CLOSED;
				}
				_mutex.lock();
				if (_closed.val) {
					result = null;
					node = null;
					return Code.CLOSED;
				}

				// There are different mode waiters
				if (!_queue.is_empty && _is_data != is_data) {
					Node<G> obj = _queue.poll();
					_mutex.unlock();
					obj.mutex.lock();
					result = (owned) obj.val;
					obj.val = (owned) val;
					obj.completed = true;
					obj.cond.broadcast();
					obj.mutex.unlock();
					node = null;
					return Code.SUCCESS;
				}

				node = new Node<G>((owned) val);
				_queue.offer(node);
				_is_data = is_data;
				_mutex.unlock();
				result = null;
				return Code.CONTINUE;
			}

			public Code check (Node<G> node, bool timed, int64 end_time, out G? result) {
				node.mutex.lock();
				while (true) {
					if (node.completed) {
						result = (owned) node.val;
						node.mutex.unlock();
						return Code.SUCCESS;
					} else if (_closed.val) {
						node.mutex.unlock();
						result = null;
						return Code.CLOSED;
					} else if (timed && get_monotonic_time() > end_time) {
						_mutex.lock();
						bool removed = _queue.remove(node);
						_mutex.unlock();
						if (!removed) continue;
						node.mutex.unlock();
						result = null;
						return Code.FAILED;
					} else {
						node.mutex.unlock();
						result = null;
						return Code.CONTINUE;
					}
				}
			}

			public Code cancel (Node<G> node, out G? result) {
				_mutex.lock();
				bool removed = _queue.remove(node);
				_mutex.unlock();
				if (!removed) {
					node.mutex.lock();
					if (node.completed) {
						result = (owned) node.val;
						node.mutex.unlock();
						return Code.SUCCESS;
					} else if (_closed.val) {
						node.mutex.unlock();
						result = null;
						return Code.CLOSED;
					} else {
						assert_not_reached();
					}
				}
				return Code.FAILED;
			}

			public Code transfer (bool is_data, owned G? val,
					bool is_try, bool timed, int64 end_time,
					out G? result) {
				Node<G>? node;
				Code res = reserve(is_data, (owned)val, is_try, timed, end_time,
						out result, out node);
				if (res != Code.CONTINUE) {
					return (!)res;
				}

				node.mutex.lock();
				while (true) {
					if (node.completed) {
						result = (owned) node.val;
						node.mutex.unlock();
						return Code.SUCCESS;
					} else if (_closed.val) {
						node.mutex.unlock();
						result = null;
						return Code.CLOSED;
					} else if (timed) {
						if ( !node.cond.wait_until(node.mutex, end_time) ) {
							_mutex.lock();
							bool removed = _queue.remove(node);
							_mutex.unlock();
							if (!removed) continue;
							node.mutex.unlock();
							result = null;
							return Code.FAILED;
						}
					} else {
						node.cond.wait(node.mutex);
					}
				}
			}
		}

		private class Node<G> {
			public G? val;
			public bool completed;
			public Mutex mutex;
			public Cond cond;

			public Node (owned G val) {
				this.val = (owned) val;
				mutex = Mutex();
				cond = Cond();
			}
		}
	}
}
