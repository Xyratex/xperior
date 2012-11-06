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
		tgroup: 0,
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
			total: 1
		}
	};
	r.branch = this.extoptions.branch;
	r.status.ofed = this.extoptions.ofed;
	r.status.distr = this.extoptions.distr;
	r.status.arch = this.extoptions.arch;
	r.status.type = this.extoptions.type;

	r.id =
          this.extoptions.branch + "_"
        + this.groupname + "_"
        + this.extoptions.type + "_"
        + this.extoptions.ofed + "_"
        + this.extoptions.arch + "_"
        + this.extoptions.distr;

    r.tgroup = this.groupname;

	r.status.date = this.extoptions.sessionstarttime;
	r.status.config = this.extoptions.configuration;
	if (this.status_code == 0) {
		r.status.passed = 1;
	} else if (this.status_code == 1) {
		r.status.failed = 1;
	} else if (this.status_code == 2) {
		r.status.skipped = 1;
	}
	emit(r.id, r);
}

