#!/usr/bin/perl

package Mail::Summary::Tools::Summary;
use Moose;

use Mail::Summary::Tools::Summary::List;

use YAML::Syck ();
use Scalar::Util ();

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

has _message_id_index => (
	isa => "HashRef",
	is  => "rw",
	default => sub { return {} },
);

sub add_lists {
	my ( $self, @lists ) = @_;
	push @{ $self->lists }, @lists;
}

sub get_thread_by_id {
	my ( $self, $message_id ) = @_;

	$self->_message_id_index->{$message_id} ||= $self->_get_thread_by_id($message_id);
}

sub _get_thread_by_id {
	my ( $self, $message_id ) = @_;

	foreach my $list ( $self->lists ) {
		if ( my $thread = $list->get_thread_by_id($message_id) ) {
			return $thread;
		}
	}

	return;
}

sub load {
	my ( $class, $thing, %options ) = @_;

	$options{$_} ||= {} for qw/summary list thread/;

	local $YAML::Syck::ImplicitUnicode = 1;
	my $hash = ref($thing) ? $thing : YAML::Syck::LoadFile($thing);

	$hash->{lists} = [ map { Mail::Summary::Tools::Summary::List->load( $_, %options ) } @{ $hash->{lists} } ];

	$class->new( %{ $options{summary} }, %$hash );
}

sub save {
	my ( $self, @args ) = @_;

	local $YAML::Syck::ImplicitUnicode = 1;

	# YAML.pm's output is prettier
	my ( $dump, $dumpfile ) = eval { require YAML; ( \&YAML::Dump, \&YAML::DumpFile ) };
	$dump     ||= \&YAML::Syck::Dump;
	$dumpfile ||= \&YAML::Syck::DumpFile;

	if ( @args ) {
		my $file = shift @args;
		unlink "$file~";
		rename $file, "$file~";
		return $dumpfile->( $file, $self->to_hash );
	} else {
		return $dump->( $self->to_hash );
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


