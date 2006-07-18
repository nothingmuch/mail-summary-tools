#!/usr/bin/perl

package Mail::Summary::Tools::CLI::Create;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use DateTime::Format::DateManip;
use DateTime::Infinite;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Summary::List;
use Mail::Summary::Tools::Summary::Thread;
use Mail::Summary::Tools::ThreadLoader;
use Mail::Summary::Tools::ThreadFilter;
use Mail::Summary::Tools::ThreadFilter::Util qw/
	get_root_message
	thread_root last_in_thread any_in_thread all_in_thread
	negate
	mailing_list_is in_date_range
/; # subject_matches

use constant options => (
	'v|verbose'   => "verbose",
	'i|input=s'   => "input",
	'o|output=s'  => "input",
	'f|from=s'    => "from",
	't|to=s'      => "to",
	'l|list=s'    => "list",
	's|subject=s' => "subject", # TODO
	'p|posters'   => "posters",
	'm|match=s'   => "match", # TODO
	'c|clean'   => "clean",
);

sub load_threads {
	my ( $self, $folder ) = @_;

	my $thr = Mail::Summary::Tools::ThreadLoader->new;
	return $thr->threads( folder => $folder );
}

sub construct_filters {
	my $self = shift;

	return (
		$self->construct_date_filter,
		$self->construct_list_filter,
		$self->construct_subject_filter,
	);
}

sub construct_date_filter {
	my $self = shift;

	my $from = DateTime::Format::DateManip->parse_datetime( $self->{from} || return );
	my $to   = DateTime::Format::DateManip->parse_datetime( $self->{to} || return );

	if ( $from || $to ) {
		$from ||= DatTime::Infinite::Past->new;
		$to ||= DatTime::Infinite::Future->new;

		return $self->comb_filter( in_date_range( $from, $to ) );
	} else {
		die "From or to date specification is invalid\n";
	}
}

sub construct_list_filter {
	my $self = shift;

	if ( my $list = $self->{list} ) {
		return $self->comb_filter( mailing_list_is($list) );
	} else {
		return;
	}
}

sub construct_subject_filter {
	return;
}

sub comb_filter {
	my ( $self, $filter ) = @_;
	any_in_thread( $filter );
}

sub filter {
	my ( $self, $threads ) = @_;

	my $f = Mail::Summary::Tools::ThreadFilter->new(
		filters => [ $self->construct_filters ],
	);

	return $f->filter( $threads );
}

sub clean_subject {
	my ( $self, $subject ) = @_;

	return $subject unless $self->{clean};


	$subject =~ s/^\s*(?:Re|Fwd):\s*//i;
	$subject =~ s/^\s*\[[\w-]+\]\s*//; # remove [Listname] munging

	return $subject;
}

sub run {
	my ( $self, @args ) = @_;
	@args and $self->{$_} = shift @args for qw/output input/;

	my $folder      = $self->{input}  || die "Must provide a mail box for input\n";
	my $summary_out = $self->{output} || die "Must provide output yaml file for output\n";

	my $threads = $self->load_threads( $folder );

	my @threads = $self->filter( $threads );

	my $list = Mail::Summary::Tools::Summary::List->new( $self->{list} ? (name => $self->{list}) : () );
	my $summary = Mail::Summary::Tools::Summary->new( lists => [ $list ] );

	foreach my $thread ( @threads ) {
		my $message = get_root_message($thread);
		my $summarized_thread = Mail::Summary::Tools::Summary::Thread->from_mailbox_thread( $thread,
			collect_posters => $self->{posters},
			process_subject => sub { $self->clean_subject(shift) },
		);

		#$summarized_thread->extra->{ .... } = { ... }

		$list->add_threads( $summarized_thread );
	}

	$summary->save( $summary_out );
}

__PACKAGE__;

__END__

=pod

=head1 USAGE

	create summary.yaml foo.mbox

=head1 SYNOPSIS

	--verbose                   Not yet implemented.
	--input=MAILBOX             Something you can pass to Mail::Box::Manager.
	--output=FILE.yaml          A yaml file to write to.
	--from=DATE                 Something that Date::Manip can parse
	--to=DATE				
	--list=name                 Only messages for a mailing list by that name.
	--subject=PATTERN           Filter by subject
	--posters                   Extract all posters in a thread
	--match=any|all|root|last	Which messages must match the filters for a
	                            thread to be included.
	--clean                     Try to clean the subject line.

=head1 DESCRIPTION

=cut


