#!/usr/bin/perl

package Mail::Summary::Tools::ThreadLoader;
use Moose;

use Mail::Box::Manager;

has mailbox_manager => (
	isa => "Mail::Box::Thread::Manager",
	is  => "rw",
	handles => [qw/open/],
	lazy    => 1,
	default => sub { Mail::Box::Manager->new }
);

sub threads {
	my ( $self, %options ) = @_;

	my $folder = $options{folder};
	unless ( blessed($folder) ) {
		$folder = $self->open( %options );
	}

	return $self->mailbox_manager->threads( $folder );
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::ThreadLoader - Idiotic wrapper around Mail::Box::manager.

=head1 SYNOPSIS

	use Mail::Summary::Tools::ThreadLoader;

=head1 DESCRIPTION

=cut


