/* SumInt64Collector.vala
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

using Gee;

private class Gpseq.Collectors.SumInt64Collector<G> : Object, Collector<int64?,Accumulator,G> {
	private MapFunc<int64?,G> _mapper;

	public SumInt64Collector (owned MapFunc<int64?,G> mapper) {
		_mapper = (owned) mapper;
	}

	public CollectorFeatures features {
		get {
			return 0;
		}
	}

	public Accumulator create_accumulator () throws Error {
		return new Accumulator(0);
	}

	public void accumulate (G g, Accumulator a) throws Error {
		Overflow.int64_add(a.val, _mapper(g), out a.val);
	}

	public Accumulator combine (Accumulator a, Accumulator b) throws Error {
		Overflow.int64_add(a.val, b.val, out a.val);
		return a;
	}

	public int64? finish (Accumulator a) throws Error {
		return a.val;
	}

	public class Accumulator : Object {
		public int64 val;
		public Accumulator (int64 val) {
			this.val = val;
		}
	}
}
