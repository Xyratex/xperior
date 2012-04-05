function(k, values) {
	var r = {
        id    : 0,
        ofed  : 0,
        distr : 0,
        arch  : 0,
        type  : 0,
		branch: 0,
		date: 0,
		config: 0,
		status: {
			passed: 0,
			failed: 0,
			skipped: 0,
			total: 0 //!!!! there is difference from map definition!
		}
	};
	values.forEach(function(value) {
		r.id     = value.id;
        r.ofed   = value.ofed;
        r.distr  = value.distr;
        r.type   = value.type;
        r.arch   = value.arch;
		r.branch = value.branch;
		r.config = value.config
		r.date   = value.date;
		r.status.passed += value.status.passed;
		r.status.failed += value.status.failed;
		r.status.skipped += value.status.skipped;
		r.status.total += 1;
	});
	return r;
}

