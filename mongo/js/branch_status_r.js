function(k, values) {
/*
* GPL HEADER START
*
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
*
* This program is free software; you can redistribute it and/or modify
* it under the terms of the GNU General Public License version 2 only,
* as published by the Free Software Foundation.
*
* This program is distributed in the hope that it will be useful, but
* WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License version 2 for more details (a copy is included
* in the LICENSE file that accompanied this code).
*
* You should have received a copy of the GNU General Public License
* version 2 along with this program; If not, see http://www.gnu.org/licenses
*
* Please  visit http://www.xyratex.com/contact if you need additional information or
* have any questions.
*
* GPL HEADER END
*/

/*
* Copyright 2012 Xyratex Technology Limited
* Author: Roman Grigoryev<Roman_Grigoryev@xyratex.com>
*/

	var r = {
		id: 0,
		tgroup: 0,
        branch: 0,
		status: {
			ofed: 0,
			distr: 0,
			arch: 0,
			type: 0,
			date: 0,
			config: 0,
			passed: 0,
			failed: 0,
			skipped: 0,
			total: 0 //!!!! there is difference from map definition!

		}
	};
	
    values.forEach(function(value) {
		r.id     = value.id;
        r.tgroup = value.tgroup;
        r.status.ofed   = value.status.ofed;
        r.status.distr  = value.status.distr;
        r.status.type   = value.status.type;
        r.status.arch   = value.status.arch;
		r.branch = value.branch;
		r.status.config = value.status.config
		r.status.date   = value.status.date;
		r.status.passed += value.status.passed;
		r.status.failed += value.status.failed;
		r.status.skipped += value.status.skipped;
		r.status.total += 1;
	});
	return r;
}

