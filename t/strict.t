#!perl -w

use strict;
use warnings;

use Test::Most;

if($ENV{AUTHOR_TESTING}) {
	eval 'use Test::Strict';
	if($@) {
		plan(skip_all => 'Test::Strict required for testing use strict');
	} else {
		all_perl_files_ok();
		warnings_ok('lib/Locale/Places.pm');
		warnings_ok('lib/Locale/Places/GB.pm');
	}
} else {
	plan(skip_all => 'Author tests not required for installation');
}
