/* AtomicBoolRef.vala
 *
 * Copyright (C) 2019  Космос Преда́ние (kosmospredanie@yandex.ru)
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
	 * A bool value that guarantees atomic update
	 */
	internal class AtomicBoolRef : Object {
		private const int FALSE = 0;
		private const int TRUE = 1;

		private int _val;

		public AtomicBoolRef (bool val = false) {
			_val = val ? TRUE : FALSE;
		}

		public bool val {
			get {
				return TRUE == AtomicInt.get(ref _val);
			}
			set {
				AtomicInt.set(ref _val, value ? TRUE : FALSE);
			}
		}
	}
}
