#!/usr/bin/perl

package Mail::Summary::Tools::FlatFile;
use Moose;

use File::Slurp ();

has summary => (
	isa => "Mail::Summary::Tools::Summary",
	is  => "rw",
	required => 1,
);

has message_id_index => (
	isa => "HashRef",
	is  => "rw",
	lazy => 1,
	default => sub { $_[0]->compute_message_id_index },
);

has uri_type => (
	isa => "Str",
	is  => "rw",
	default => "thread_uri",
);

has skip_summarized => (
	isa => "Bool",
	is  => "rw",
	default => 0,
);

has list_posters => (
	isa => "Bool",
	is  => "rw",
	default => 0,
);

has add_links => (
	isa => "Bool",
	is  => "rw",
	default => 0,
);

has list_dates => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

has list_misc => (
    isa => "Bool",
    is  => "rw",
    default => 0,
);

sub save {
	my ( $self, $file ) = @_;

	my $text = $self->emit_summary( $self->summary );

	if ( $file ) {
		File::Slurp::write_file( $file, $text );
	}

	$text;
}

sub load {
	my ( $self, $text ) = @_;

	$text = File::Slurp::read_file($text) unless $text =~ qr/---/;

	# filter out comments
	$text =~ s/^#.*$//mg;

	foreach my $thread ( grep { length($_) } split /\s*\n---\n\s*/, $text ) {
		$self->load_thread( $thread );
	}	
}

sub load_thread {
	my ( $self, $text ) = @_;

	my ( $head, $summary ) = split /\n\n\s*/, $text, 2;
	my ($id) = split /\n/, $head;

	my $thread = $self->message_id_index->{$id}
		|| die "There is no thread with the message ID <$id> in the current summary";

	$thread->summary($summary);
}

sub compute_message_id_index {
	my $self = shift;
	return { map { $_->message_id => $_  } map { $_->threads } $self->summary->lists };
}

sub emit_summary {
	my ( $self, $summary ) = @_;
	return <<'PRE' . join("\n", map { $self->emit_list($_) } $summary->lists );
# Threads are separated with the sequence "\n---\n"
# The first line of the thread is the message ID.
# everything from the message ID to the next empty line is
# ignored. Everything up to the next separator is the summary,
# which should be written in the Markdown markup language.

# the -s option skips entries that have already been summarized
# the -l option creates links to threads (-a gmane, -a google to set archive)
# the -p option lists all the posters in the thread

---
PRE
}

sub emit_list {
	my ( $self, $list ) = @_;
	join("", map { "$_\n\n---\n" } map { $self->emit_thread($_) } $list->threads );
}

sub emit_thread {
	my ( $self, $thread ) = @_;	

	return if $self->skip_summarized and $thread->summary;

	return join("\n",
		$thread->message_id,
		$self->emit_head($thread),
		"",
		$self->emit_body($thread),
	);
}

sub emit_body {
	my ( $self, $thread ) = @_;

	return $thread->summary || "";
}

sub emit_head {
	my ( $self, $thread ) = @_;

	my $uri_type = $self->uri_type;

	my @lines = ( sprintf "Subject: %s", $thread->subject );

    if ( $self->add_links ) {
        push @lines, sprintf "<%s>", $thread->archive_link->$uri_type || "couldn't find link";
    }

	if ( $self->list_dates ) {
	   push @lines, sprintf "Start date: %s", scalar(localtime($thread->extra->{date_from})) if $thread->extra->{date_from};
	   push @lines, sprintf "End date: %s",   scalar(localtime($thread->extra->{date_to}))   if $thread->extra->{date_to};
    }
    
    if ( $self->list_misc ) {
        push @lines, "RT-Ticket: %s", $thread->extra->{rt_ticket} if $thread->extra->{rt_ticket};
    }

	if ( $self->list_posters and my $extra = $thread->extra ) {
		if ( my $posters = $extra->{posters} ) {
			push @lines, grep { defined } map { $_->{name} } @$posters;
		}
	}

	join("\n", @lines );
}


__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::FlatFile - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::FlatFile;

=head1 DESCRIPTION

=cut


