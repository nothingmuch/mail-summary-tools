#!/usr/bin/perl

package Mail::Summary::Tools::ThreadFilter;
use Moose;

has filters => (
	isa => "ArrayRef",
	is  => "rw",
	required   => 1,
	auto_deref => 1,
);

sub filter {
	my ( $self, $threads ) = @_;

	my @matches;
	thread: foreach my $thread ( $threads->all ) {
		foreach my $filter ( $self->filters ) {
			next thread unless $filter->( $thread );
		}

		push @matches, $thread;
	}

	return @matches;
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::ThreadFilter - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::ThreadFilter;

=head1 DESCRIPTION

=cut


