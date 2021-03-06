/* UnboundedChannelTests.vala
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

using Gpseq;

public abstract class UnboundedChannelTests<G> : ChannelTests<G> {
	public static void register_all () {
		new Int().register();
		new NullableInt().register();
		new String().register();
		new NullableString().register();
		new ObjTests().register();
	}

	protected UnboundedChannelTests (string name) {
		base(name, 8192);
	}

	protected override Channel<G> create_channel (int cap) {
		return Channel.unbounded<G>();
	}

	public class Int : UnboundedChannelTests<int> {
		public Int () {
			base("channel:unbounded<int>");
		}

		protected override bool equal (int a, int b) {
			return a == b;
		}

		protected override int gen (int key) {
			return key;
		}
	}

	public class NullableInt : UnboundedChannelTests<int?> {
		public NullableInt () {
			base("channel:unbounded<int?>");
		}

		protected override bool equal (int? a, int? b) {
			return a == b;
		}

		protected override int? gen (int key) {
			return key;
		}
	}

	public class String : UnboundedChannelTests<string> {
		public String () {
			base("channel:unbounded<string>");
		}

		protected override bool equal (string a, string b) {
			return a == b;
		}

		protected override string gen (int key) {
			return key.to_string();
		}
	}

	public class NullableString : UnboundedChannelTests<string?> {
		public NullableString () {
			base("channel:unbounded<string?>");
		}

		protected override bool equal (string? a, string? b) {
			return a == b;
		}

		protected override string? gen (int key) {
			return key.to_string();
		}
	}

	public class ObjTests : UnboundedChannelTests<Obj> {
		private static int64 objects;

		public ObjTests () {
			base("channel:unbounded<Obj>");
		}

		public override void set_up () {
			assert(atomic_int64_get(ref objects) == 0);
		}

		public override void tear_down () {
			Thread.usleep(500000); // Wait object finalizations
			assert(atomic_int64_get(ref objects) == 0);
		}

		protected override bool equal (Obj a, Obj b) {
			return a.val == b.val;
		}

		protected override Obj gen (int key) {
			return new Obj(key);
		}

		public class Obj : Object {
			public int val;

			public Obj (int val) {
				this.val = val;
				atomic_int64_inc(ref objects);
			}

			~Obj () {
				atomic_int64_dec_and_test(ref objects);
			}
		}
	}
}
