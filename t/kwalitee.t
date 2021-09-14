use strict;
use warnings;

use Test::Most;

my $has_test_kwalitee;

BEGIN {
	if($ENV{AUTHOR_TESTING}) {
		eval { use Test::Kwalitee tests => [ qw( -has_meta_yml ) ] };

		$has_test_kwalitee = 1 unless($@);
	}
}

if($ENV{AUTHOR_TESTING}) {
	if($has_test_kwalitee) {
		plan(skip_all => 'Test::Kwalitee not installed; skipping') if $@;

		unlink 'Debian_CPANTS.txt' if -e 'Debian_CPANTS.txt';
	} else {
		plan(skip_all => 'Author tests not required for installation');
	}
}
