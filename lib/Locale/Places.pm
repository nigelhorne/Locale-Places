package Locale::Places;

use strict;
use warnings;

use CHI;
use Locale::Places::DB::GB;
use Module::Info;

our %gb_cache;

=head1 NAME

Locale::Places - Translate places using http://download.geonames.org/

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 METHODS

=head2 new

=cut

sub new {
	my($proto, %param) = @_;
	my $class = ref($proto) || $proto;

	# Use Geo::Coder::Free->new, not Geo::Coder::Free::new
	return unless($class);

	# Geo::Coder::Free::DB::init(directory => 'lib/Geo/Coder/Free/databases');

	my $directory = $param{'directory'} || Module::Info->new_from_loaded(__PACKAGE__)->file();
	$directory =~ s/\.pm$//;

	Locale::Places::DB::init({
		directory => File::Spec->catfile($directory, 'databases'),
		cache => $param{cache} || CHI->new(driver => 'Memory', datastore => {})
	});

	return bless { }, $class;
}

1;
