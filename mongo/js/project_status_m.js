function() {
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
		ofed: 0,
		distr: 0,
		arch: 0,
		type: 0,
		branch: 0,
		date: 0,
		configurations: {},
		/*
		config: 0,
        status: {
			passed: 0,
			failed: 0,
			skipped: 0,
			total: 1
		}
        */
	};
	r.branch = this.extoptions.branch;
	r.ofed = this.extoptions.ofed;
	r.distr = this.extoptions.distr;
	r.arch = this.extoptions.arch;
	r.type = this.extoptions.type;

	r.id = this.extoptions.branch + "_" + this.extoptions.type + "_" + this.extoptions.ofed + "_" + this.extoptions.arch + "_" + this.extoptions.distr;

	r.date = this.extoptions.sessionstarttime;
	var cfg = this.extoptions.configuration;
	r.configurations[cfg] = {};
	r.configurations[cfg].name = cfg;
	r.configurations[cfg].passed = 0;
	r.configurations[cfg].failed = 0;
	r.configurations[cfg].skipped = 0;
	r.configurations[cfg].total = 1;

	if (this.status_code == 0) {
		r.configurations[cfg]['passed'] = 1;
	} else if (this.status_code == 1) {
		r.configurations[cfg]['failed'] = 1;
	} else if (this.status_code == 2) {
		r.configurations[cfg]['skipped'] = 1;
	}
	//print("doc after map  v:" + tojson(r));
	emit(r.id, r);
}

