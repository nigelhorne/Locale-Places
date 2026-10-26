#!/usr/bin/env perl

# FIXME: we shouldn't be downloading in the Makefile - move that to a script

use strict;
use warnings;

use Config;
use ExtUtils::MakeMaker;
use IO::Socket::INET;

use constant CHECK_INTERVAL => 7;	# Days between checks for newer GeoNames data

my $site;
my $data_dir = 'lib/Locale/Places/data';

# Test for broken smokers that don't set AUTOMATED_TESTING
if(my $reporter = $ENV{'PERL_CPAN_REPORTER_CONFIG'}) {
	if($reporter =~ /smoker/i) {
		warn 'AUTOMATED_TESTING added for you' if(!defined($ENV{'AUTOMATED_TESTING'}));
		$ENV{'AUTOMATED_TESTING'} = 1;
		$ENV{'NO_NETWORK_TESTING'} = 1;
	}
}

my @countries;

if(defined($ENV{'GITHUB_ACTION'}) || defined($ENV{'CIRCLECI'}) || defined($ENV{'TRAVIS_PERL_VERSION'}) || defined($ENV{'APPVEYOR'})) {
	# Prevent downloading and installing stuff
	warn 'AUTOMATED_TESTING added for you' if(!defined($ENV{'AUTOMATED_TESTING'}));
	$ENV{'AUTOMATED_TESTING'} = 1;
	$ENV{'NO_NETWORK_TESTING'} = 1;
} elsif((!defined($ENV{'AUTOMATED_TESTING'})) && (!defined($ENV{'NO_NETWORK_TESTING'}))) {
	$site = 'download.geonames.org';
	@countries = ('GB', 'US');
}

my $build_requires = {};
my $test_requires = {
	'Test::Carp' => 0,
	'Test::DescribeMe' => 0,
	'Test::Log::Abstraction' => 0,
	'Test::Most' => 0,
	'Test::Needs' => 0,
	'Test::RequiresInternet' => 0
};

if(scalar(@countries)) {
	$build_requires = {	# For bin/create_sqlite
		'DBI' => 0,
		'File::Copy' => 0,
	};
	$test_requires->{'autodie'} = 0;

	if(! -d $data_dir) {
		print "Creating the download directory $data_dir\n";
		mkdir $data_dir or die "Failed to create directory $data_dir: $!";
	}

	# Only go to the network for countries that haven't been checked recently
	my @stale = grep { !is_fresh($_) } @countries;

	if(scalar(@stale)) {
		if(IO::Socket::INET->new(PeerAddr => "$site:443", Timeout => 5)) {
			foreach my $country(@stale) {
				fetch_country($country);
			}
		} elsif(grep { !-r "$data_dir/$_.csv" } @countries) {
			print STDERR "NA: Can't connect to $site\n";
			exit(0);
		} else {
			print STDERR "Can't connect to $site, using the existing data\n";
		}
	} else {
		print "Downloaded data was checked less than ", CHECK_INTERVAL, " days ago\n";
	}

	# my $pm = {
		# 'lib/Locale/Places.pm' => 'blib/lib/Locale/Places.pm',
		# 'lib/Locale/Places/DB.pm' => 'blib/lib/Locale/Places/DB.pm',
		# 'lib/Locale/Places/DB/GB.pm' => 'blib/lib/Locale/Places/DB/GB.pm',
	# };

	# if($ENV{'AUTOMATED_TESTING'}) {
		# $pm->{'lib/Locale/Places/data/GB.csv'} = 'blib/lib/Locale/Places/data/GB.csv';
	# } else {
		# $pm->{'lib/Locale/Places/data/GB.sql'} = 'blib/lib/Locale/Places/data/GB.sql';
	# }

	if($Config{'osname'} ne 'MSWin32') {
		$build_requires->{'File::Open::NoCache::ReadOnly'} = 0.06;
		$build_requires->{'IO::AIO'} = 0;
	}
} else {
	# Remove the data directory on smokers, CircleCI in particular can leave some around
	my @dirs = (
		'lib/Locale/Places/data',
		'blib/lib/Locale/Places/data',
	);
	foreach my $dir(@dirs) {
		if(-d $dir) {
			print "Removing the download directory $dir\n";
			while(my $file = glob("$dir/*")) {
				unlink $file || die "$file: $!";
			}
			rmdir $dir || die "$dir: $!";
		}
	}
}

my $dist = {
	COMPRESS => 'gzip -9f',
	SUFFIX => 'gz'
};

if($^O eq 'darwin') {
	$dist->{'TAR'} = 'gtar';
}

WriteMakefile(
	NAME		=> 'Locale::Places',
	AUTHOR		=> q{Nigel Horne <njh@nigelhorne.com>},
	VERSION_FROM	=> 'lib/Locale/Places.pm',
	ABSTRACT_FROM   => 'lib/Locale/Places.pm',
	((defined($ExtUtils::MakeMaker::VERSION) &&
	 ($ExtUtils::MakeMaker::VERSION >= 6.3002))
	  ? ('LICENSE'=> 'GPL')
	  : ()),
	BUILD_REQUIRES => $build_requires,
	CONFIGURE_REQUIRES => {
		'Config' => 0,
		'ExtUtils::MakeMaker' => 6.64,	# 6.64 for TEST_REQUIRES
		'File::Which' => 0,
		'HTTP::Tiny' => 0,
		'IO::Uncompress::Unzip' => 0,
		'LWP::UserAgent' => 0,
		'Try::Tiny' => 0,
	}, TEST_REQUIRES => $test_requires,
	PREREQ_PM => {
		'CHI' => 0,
		'Database::Abstraction' => 0.04,
		'DBI' => 0,
		'DBD::CSV' => 0,
		'DBD::SQLite' => 0,
		'DBD::SQLite::Constants' => 0,
		'Error::Simple' => 0,
		'File::pfopen' => 0,
		'File::Spec' => 0,
		'I18N::LangTags::Detect' => 0,
		'Module::Info' => 0,
		'Object::Configure' => 0.24,
		'Params::Get' => 0.17,
		'Params::Validate::Strict' => 0.41,
		'Scalar::Util' => 0,
		'Text::CSV' => 0,
		'Text::xSV::Slurp' => 0
	}, dist => $dist,
	clean	=> { FILES => 'Locale-Places-* lib/Locale/Places/data/*' },
	EXE_FILES	=> [ 'bin/translate' ],
	# META_ADD => {
		# provides => { }
	# },
	META_MERGE		=> {
		'meta-spec' => { version => 2 },
		resources => {
			homepage => 'https://metacpan.org/pod/Locale::Places',
			repository => {
				repository => 'https://github.com/nigelhorne/Locale-Places',
				type => 'git',
				url => 'git://github.com/nigelhorne/Locale-Places.git',
				web => 'https://github.com/nigelhorne/Locale-Places',
				# license    => 'http://dev.perl.org/licenses/',
			}, bugtracker => {
				mailto => 'bug-Locale-Places@rt.cpan.org',
				url => 'https://github.com/nigelhorne/Locale-Places/issues',
				# web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Locale-Places',
				web => 'https://github.com/nigelhorne/Locale-Places/issues'
			}
		},
	}, PL_FILES => (defined($ENV{'AUTOMATED_TESTING'}) ? {} : {'bin/create_db.PL' => 'bin/create_db'}),
	# , PM => $pm,
	# PPM_INSTALL_EXEC	=> 'bash',
	# PPM_INSTALL_SCRIPT	=> 'bin/create_sqlite',
	MIN_PERL_VERSION	=> '5.14.0'	# Minimum version that HTTP::Tiny is in the core
);

# Has $country been downloaded and checked for updates recently?
sub is_fresh
{
	my $country = shift;

	my $stamp = "$data_dir/$country.checked";

	return (-r "$data_dir/$country.csv") && (-r $stamp) && (-M $stamp < CHECK_INTERVAL);
}

# Fetch $country.zip only if the server has a newer copy, then extract it.
# The zip is kept as a 0-byte file whose mtime is the server's Last-Modified
#	time, so that the next check is a cheap If-Modified-Since request
sub fetch_country
{
	my $country = shift;

	my $url = "https://$site/export/dump/alternatenames/$country.zip";
	my $zip = "$data_dir/$country.zip";
	my $csv = "$data_dir/$country.csv";

	# Without the CSV a "304 Not Modified" would leave us with nothing to extract
	unlink $zip if(-e $zip && !-r $csv);

	if(-e $zip) {
		print "Downloading $url if a newer version is available\n";
	} else {
		print "Downloading $url\n";
	}

	my $status = mirror($url, $zip);

	if(($status == 304) && (-r $csv)) {
		print "$csv is up to date\n";
	} else {
		explode($country, $zip, $csv);

		# Save disc space, but keep the mtime for the next If-Modified-Since
		my $mtime = (stat($zip))[9];
		truncate $zip, 0 or warn "Failed to truncate $zip: $!";
		utime $mtime, $mtime, $zip;
	}

	# Record when we last checked, so that we don't hit the server on every build
	open(my $fout, '>', "$data_dir/$country.checked") or die "$data_dir/$country.checked: $!";
	close $fout;
}

# Conditional GET of $url into $file, returns the HTTP status (200 or 304)
sub mirror
{
	my ($url, $file) = @_;

	my ($status, $reason);

	require HTTP::Tiny;
	if(HTTP::Tiny->can_ssl()) {
		my $res = HTTP::Tiny->new(timeout => 60, verify_SSL => 1)->mirror($url, $file);
		($status, $reason) = ($res->{'status'}, $res->{'reason'});
		$reason .= ": $res->{content}" if($status == 599);
	} else {
		require LWP::UserAgent;
		my $res = LWP::UserAgent->new(timeout => 60)->mirror($url, $file);
		($status, $reason) = ($res->code(), $res->message());
	}

	return $status if(($status == 200) || ($status == 304));

	if($ENV{'AUTOMATED_TESTING'}) {
		print STDERR "Can't download $url: $status $reason\n";
		exit(0);
	}
	die "$url: $status $reason";
}

# Extract $country.txt from $zip into $csv, via a temporary file so that an
#	interrupted build doesn't leave a truncated CSV that looks valid
sub explode
{
	my ($country, $zip, $csv) = @_;

	print "Exploding $zip\n";

	require IO::Uncompress::Unzip;

	my $tmp = "$csv.tmp";
	open(my $fout, '>', $tmp) or die "$tmp: $!";

	my $fin = IO::Uncompress::Unzip->new($zip, Name => "$country.txt");
	if(!$fin) {
		close $fout;
		unlink $tmp;
		if($ENV{'AUTOMATED_TESTING'}) {
			print STDERR "$zip: $IO::Uncompress::Unzip::UnzipError\n";
			exit(0);
		}
		die "$zip: $IO::Uncompress::Unzip::UnzipError";
	}
	while(my $line = $fin->getline()) {
		print $fout $line or die "Error exploding $zip: $!";
	}
	$fin->close();
	close $fout or die "Failed to close $tmp: $!";

	die "Could not find $country.txt in $zip" if(!-s $tmp);

	rename $tmp, $csv or die "rename $tmp to $csv: $!";
}
