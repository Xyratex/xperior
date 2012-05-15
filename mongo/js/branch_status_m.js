function() {
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

