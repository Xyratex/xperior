function(k, values) {
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

