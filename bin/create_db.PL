#!/usr/bin/env perl

# Create SQLite3 from http://download.geonames.org/export/dump/GB.zip

use strict;
use warnings;
use Config;
use DBI;
use File::Copy;
use File::Spec;
use Try::Tiny;
use autodie qw(:all);

use	constant	AIO_READAHEAD_SIZE => 1048576;	# 1MB

sub doit($$);

BEGIN {
	$SIG{__WARN__} = sub {
		my $warning = shift;
		if(($warning =~ /^Use of uninitialized value/) ||
		   ($warning =~ /isn't numeric in numeric eq /i)) {
			die $warning;
		}
	}
}

exit if($ENV{'AUTOMATED_TESTING'});

if($Config{'osname'} ne 'MSWin32') {
	require IO::AIO;
	IO::AIO->import();

	require File::Open::NoCache::ReadOnly;
	File::Open::NoCache::ReadOnly->import();
}

my $dir = 'lib/Locale/Places/data';
foreach my $country('GB', 'US') {
	my $csv = File::Spec->catdir($dir, "$country.csv");
	my $sqlite = File::Spec->catdir($dir, "$country.sql");

	if(-r $sqlite) {
		if((-s $sqlite) > 0) {	# Non empty?
			# Don't bother building if the SQL file is less than a day old
			next if(-M $sqlite < 1);
			# Don't bother building if the SQL file is newer than the CSV file
			next if((-M $sqlite) >= (-M $csv));
		}
		unlink $sqlite;
	}

	print "Building $sqlite\n";

	my $fin;
	if($Config{'osname'} eq 'MSWin32') {
		open($fin, '<', $csv);
	} else {
		$csv = File::Open::NoCache::ReadOnly->new($csv) or die "$country: $!";
		$fin = $csv->fd();
		aio_readahead($fin, 0, AIO_READAHEAD_SIZE);
	}

	if(my $dbh = DBI->connect("dbi:SQLite:dbname=$sqlite", undef, undef, { RaiseError => 1, AutoCommit => 0, synchronous => 0, locking_mode => 'EXCLUSIVE' })) {
		my $table = lc($country);
		$dbh->do("CREATE TABLE $table(code1 INTEGER, code2 INTEGER, type VARCHAR(4), data VARCHAR NOT NULL, ispreferredname BIT, isshortname BIT)");
		# keys
		# if($place = $self->{$table}->fetchrow_hashref({ type => $from, data => $place })) {
			# if(my $line = $self->{$table}->fetchrow_hashref({ type => $to, code2 => $place->{'code2'} })) {
		$dbh->do('PRAGMA cache_size = -65536');	# 64MB
		$dbh->do('PRAGMA journal_mode = OFF');

		my $queue = doit($dbh, $fin);

		$csv = undef;

		flush($dbh, $table, $queue);

		undef $queue;

		$dbh->commit();
		$dbh->disconnect();

		File::Copy::copy($sqlite, File::Spec->catfile('blib', $sqlite));
	} else {
		die "$sqlite: $!";
	}
}

sub doit($$) {
	my ($dbh, $fin) = @_;

	my %queue;

	while(my $line = <$fin>) {
		chomp $line;

		my ($code1, $code2, $type, $data, $ispreferredname, $isshortname) = split(/\t/, $line);
		die "Can't parse the line '$line'" unless(defined($type));
		# next if($type eq 'link');
		# next if($type eq 'wkdt');
		# next if($type eq 'post');
		next if(length($type) != 2);

		# print __LINE__, ": $code1=>$data=>$ispreferredname\n";

		$queue{$code1} = {
			code1 => $code1,
			code2 => $code2,
			type => $type,
			data => $data,
		};
		if(length($ispreferredname)) {
			$queue{$code1}->{'ispreferredname'} = $ispreferredname;
		}
		if(length($isshortname)) {
			$queue{$code1}->{'isshortname'} = $isshortname;
		}
	}
	return \%queue;
}

sub flush($$$)
{
	my ($dbh, $table, $queue) = @_;

	my $query;

	while(my ($key, $value) = each (%{$queue})) {
		delete $queue->{$key};
		if(!defined($query)) {
			$query = "INSERT INTO $table(code1, code2, type, data, ispreferredname, isshortname) VALUES (";
		} else {
			$query .= ',(';
		}

		$value->{'code1'} =~ s/'/''/g;
		$value->{'code2'} =~ s/'/''/g;
		$query .= $value->{'code1'} . ",'" . $value->{'code2'} . "',";

		if($value->{'type'} && ($value->{'type'} ne '')) {
			$query .= "'" . $value->{'type'} . "',";
		} else {
			$query .= 'NULL,';
		}
		$value->{'data'} =~ s/'/''/g;
		$query .= "'" . $value->{'data'} . "',";

		if(defined($value->{'ispreferredname'})) {
			my $ispreferredname = $value->{'ispreferredname'} ? 1 : 0;
			$query .= "$ispreferredname,";
		} else {
			$query .= 'NULL,';
		}

		if(defined($value->{'isshortname'})) {
			my $isshortname = $value->{'isshortname'} ? 1 : 0;
			$query .= "$isshortname)";
		} else {
			$query .= 'NULL)';
		}

		# use Data::Dumper;
		# print Data::Dumper->new([$value])->Dump() if($ispreferredname);
	}

	try {
		$dbh->do($query);
	} catch {
		my @call_details = caller(0);
		die "Error in insert ($query) called from line ",
		# die "Error in insert called from line ",
			$call_details[2], ': ', $dbh->errstr();
	};
}
