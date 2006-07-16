#!/usr/bin/perl

package Mail::Summary::Tools::Summary::Thread;
use Moose;

has subject => (
	isa => "Str",
	is  => "rw",
	required => 1,
);

has message_id => (
	isa => "Str",
	is  => "rw",
	required => 1,
);

has extra => (
	isa => "HashRef",
	is  => "rw",
	required => 0,
);

has summary => (
	isa => "Str",
	is  => "rw",
	required => 0,
	default  => "...",
);

sub from_mailbox_thread {
	my ( $class, $thread ) = @_;

	my @messages = $thread->threadMessages;

	my $root = $messages[0];

	my $subject = $root->subject;

	my %seen_email;
	my @participants =
		map { { name => $_->name, email => $_->address } }
		grep { $seen_email{$_->address} }
		map { $_->from } @messages;

	$class->new(
		subject    => $subject,
		message_id => $root->messageId,
		participants => \@participants,
	);
}

sub load {
	my ( $class, $hash ) = @_;

	my @good_keys = qw/summary message_id subject/;

	my %hash = %$hash;

	my %good_values;
	@good_values{@good_keys} = delete @hash{@good_keys};

	$class->new(
		%good_values,
		extra => \%hash,
	);
}

sub to_hash {
	my $self = shift;

	return {
		subject    => $self->subject,
		message_id => $self->message_id,	
		summary    => $self->summary,
		($self->extra ? %{ $self->extra } : ()),
	};
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::Summary::Thread - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::Summary::Thread;

=head1 DESCRIPTION

=cut


