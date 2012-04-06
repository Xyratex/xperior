function() {
	var r = {
        id    : 0,
        ofed  : 0,
        distr : 0,
        arch  : 0,
        type  : 0,
		branch: 0,
		date  : 0,        
		config: 0,
		status: {
			passed: 0,
			failed: 0,
			skipped: 0,
			total: 1
		}
	};
	r.branch = this.extoptions.branch;
	r.ofed   = this.extoptions.ofed;
	r.distr  = this.extoptions.distr;
	r.arch   = this.extoptions.arch;
	r.type   = this.extoptions.type;



	r.id = this.extoptions.branch + "_"
         + this.extoptions.type   + "_"
         + this.extoptions.ofed   + "_"
         + this.extoptions.arch   + "_"
         + this.extoptions.distr  ;
	r.date = this.extoptions.sessionstarttime;
	r.config = this.extoptions.configuration;
	if (this.status_code == 0) {
		r.status.passed = 1;
	} else if (this.status_code == 1) {
		r.status.failed = 1;
	} else if (this.status_code == 2 ){
        r.status.skipped = 1;
    }
	emit(r.id, r);
}

