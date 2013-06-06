use Test::More tests => 12;
use Xperior::Utils;
use Log::Log4perl qw(:easy);
#Log::Log4perl->easy_init($DEBUG);

my $a, $b;
shell (["echo", "a", "b", "c"], out => \$a);
shell ("echo a b c", out => \$b);
is ($a, $b, "Single parameter vs array");
my $xout, $yout, $xerr, $yerr;
shell ("echo abc", out => \$xout, err => \$xerr);
shell ("echo abc 1>&2", out => \$yout, err => \$yerr);
is ($xout, $yerr, "Same xout and yerr");
is ($xerr, $yout, "Same empty yout and xerr");
isnt ($xout, $xerr, "X has different out and err");
isnt ($yout, $yerr, "Y has different out and err");

my $exit7 = shell ("perl -E 'exit 7'");
is($exit7, 7, "Exit code");
my $exit0 = shell ("echo ok");
is($exit0, 0, "Exit 0");
my ($exit_ok) = shell (["echo ok"]);
is($exit_ok, "ok", "Exit ok");

my $script = <<SCRIPT;
print STDOUT "a";
print STDERR "xyz";
print STDOUT "b";
print STDERR "pqr";
print STDOUT "\n";
print STDOUT "c\n";

SCRIPT

my $eout = "";
my $eerr = "";
my @gout, @gerr;
shell (["perl", "-E", "'$script'"], out => \@gout, err => \@gerr);
is_deeply ([@gout], ["ab", "c"], "Mixed stdout");
is_deeply ([@gerr], ["xyzpqr"], "Mixed stderr");
my @arr = shell ("perl -E 'print \"a\nb\nc\"'");
is_deeply ([@arr], ["a", "b", "c"], "Array output");
if (shell("echo ok")) {
    fail("Echo ok, should return 0");
}
else {
    pass("Echo ok, returned 0");
};

