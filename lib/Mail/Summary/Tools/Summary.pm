#!/usr/bin/perl

package Mail::Summary::Tools::Summary;
use Moose;

use Mail::Summary::Tools::Summary::List;

use YAML::Syck;

has title => (
	isa => "Str",
	is  => "rw",
);

has lists => (
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

sub add_lists {
	my ( $self, @lists ) = @_;
	push @{ $self->lists }, @lists;
}

sub load {
	my ( $class, $thing, %options ) = @_;

	$options{$_} ||= {} for qw/summary list thread/;

	my $hash = ref($thing) ? $thing : YAML::Syck::LoadFile($thing);

	$hash->{lists} = [ map { Mail::Summary::Tools::Summary::List->load( $_, %options ) } @{ $hash->{lists} } ];

	$class->new( %{ $options{summary} }, %$hash );
}

sub save {
	my ( $self, @args ) = @_;

	# YAML.pm's output is prettier

	require YAML;

	if ( @args ) {
		my $file = shift @args;
		return YAML::DumpFile( $file, $self->to_hash );
	} else {
		return YAML::Dump( $self->to_hash );
	}
}

sub to_hash {
	my $self = shift;

	return {
		( $self->title ? (title => $self->title) : () ),
		( $self->extra ? (extra => $self->extra) : () ),
		lists => [ map { $_->to_hash } $self->lists ],
	};
}




__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::Summary - A simple summary format for multiple mailing
lists

=head1 SYNOPSIS

	use Mail::Summary::Tools::Summary;

=head1 DESCRIPTION

=cut


