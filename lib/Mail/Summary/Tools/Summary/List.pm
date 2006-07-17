#!/usr/bin/perl

package Mail::Summary::Tools::Summary::List;
use Moose;

use Mail::Summary::Tools::Summary::Thread;

has name => (
	isa => "Str",
	is  => "rw",
	required => 1,
);

has title => (
	isa  => "Str",
	is   => "rw",
	lazy => 1,
	default => sub { $_[0]->name },
);

has threads => (
	isa => "ArrayRef",
	is  => "rw",
	auto_deref => 1,
	default    => sub { [ ] },
);

has extra => (
	isa => "HashRef",
	is  => "rw",
	required => 0,
);

sub add_threads {
	my ( $self, @threads ) = @_;
	push @{ $self->threads }, @threads;
}

sub load {
	my ( $class, $hash, %options ) = @_;

	$hash->{threads} = [ map { Mail::Summary::Tools::Summary::Thread->load($_, %options) } @{ $hash->{threads} } ];

	$class->new( %{ $options{list} }, %$hash );
}

sub to_hash {
	my $self = shift;

	return {
		name  => $self->name,
		title => $self->title,
		threads => [ map { $_->to_hash } $self->threads ],
		( $self->extra ? ( extra => $self->extra ) : () ),
	};
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::Summary::List - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::Summary::List;

=head1 DESCRIPTION

=cut


