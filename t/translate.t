#!perl -wT

use strict;
use warnings;
use Test::Most tests => 6;

BEGIN {
	use_ok('Locale::Places');
}

TRANSLATE: {
	my $places = new_ok('Locale::Places');

	like($places->translate(place => 'London', language => 'fr'), qr/Londres$/, 'French for London is Londres');
	is($places->translate({ place => 'foo', language => 'bar' }), undef, 'Translating gibberish returns undef');

	$ENV{'LANGUAGE'} = 'en';
	is($places->translate('Dover'), 'Dover', 'LANGUAGE set to English');

	delete $ENV{'LANGUAGE'};
	$ENV{'LANG'} = 'fr_FR';
	is($places->translate('Dover'), 'Douvres', 'LANG set to French');
}
