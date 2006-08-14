#!/usr/bin/perl

package Mail::Summary::Tools::CLI::Create;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use DateTime::Format::DateManip;
use DateTime::Infinite;


use Mail::Box::Manager;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Summary::List;
use Mail::Summary::Tools::Summary::Thread;
use Mail::Summary::Tools::ThreadFilter;
use Mail::Summary::Tools::ThreadFilter::Util qw/
	get_root_message guess_mailing_list
	thread_root last_in_thread any_in_thread all_in_thread
	negate
	mailing_list_is in_date_range
/; # subject_matches

use constant options => (
	'v|verbose'   => "verbose",
	'i|input=s@'  => "input",
	'o|output=s'  => "output",
	'u|update'    => "update",
	'f|from=s'    => "from",
	't|to=s'      => "to",
	'l|list=s'    => "list",
	's|subject=s' => "subject", # TODO
	'p|posters'   => "posters",
	'd|dates'     => "dates",
	'm|match=s'   => "match", # TODO
	'c|clean'     => "clean",
	'r|rt'        => "rt",
);

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

	if ( defined($from) || defined($to) ) {
		$from = DateTime::Infinite::Past->new   unless defined($from);
		$to   = DateTime::Infinite::Future->new unless defined($to);

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
	my ( $self, @params ) = @_;

	my $f = Mail::Summary::Tools::ThreadFilter->new(
		filters => [ $self->construct_filters ],
	);

	return $f->filter(@params);
}

sub clean_subject {
	my ( $self, $subject ) = @_;

	return $subject unless $self->{clean};

	$subject =~ s/^\s*(?:Re|Fwd):\s*//i;
	$subject =~ s/^\s*\[[\w-]+\]\s*//; # remove [Listname] munging
	$subject =~ s/^\s*|\s*$//g; # strip whitespace

	return $subject;
}

sub run {
	my ( $self, @args ) = @_;
	@args and $self->{$_} ||= shift @args for qw/output/;
	push @{ $self->{input} }, @args;

	my @folders     = @{ $self->{input} } or die "Must provide at least one mail box for input\n";
	my $summary_out = $self->{output}     or die "Must provide output yaml file for output\n";

	if ( -f $summary_out and !$self->{update} ) {
		die "The output file '$summary_out' exists. Either remove it or specify the --update option\n";
	}
	
	my $summary = -f $summary_out
		? Mail::Summary::Tools::Summary->load( $summary_out )
		: Mail::Summary::Tools::Summary->new;

	$self->diag("loading and threading mailboxes: @folders");

	my $mgr = Mail::Box::Manager->new;
	my $threads = $mgr->threads(
		folders  => [ map { $mgr->open( folder => $_ ) } @folders ],
		timespan => 'EVER',
		window   => 'ALL',
		( $self->{verbose} ? (trace => "PROGRESS") : ()),
	);

	my %lists = map { $_->name => $_ } $summary->lists;
	my %seen;

	$self->filter( threads => $threads, callback => sub {
		my $thread = shift;
		
		my $root = get_root_message($thread);
		next if $seen{$root->messageId}++;

		my $list_name = eval { guess_mailing_list($root)->listname };
		my $list_key = $list_name || "unknown";

		my $list = $lists{$list_key} ||= do {	
			my $list = Mail::Summary::Tools::Summary::List->new( $list_name ? (name => $list_name) : () );
			$summary->add_lists( $list );
			$list;
		};

		my $summarized_thread = Mail::Summary::Tools::Summary::Thread->from_mailbox_thread( $thread,
			collect_posters => $self->{posters},
			collect_dates   => $self->{dates},
			collect_rt      => $self->{dates},
			process_subject => sub { $self->clean_subject(shift) },
		);

		#$summarized_thread->extra->{ .... } = { ... }

		if ( my $existing = $summary->get_thread_by_id( $summarized_thread->message_id ) ) {
			my $was_out_of_date = $existing->extra->{out_of_date};
			$existing->merge( $summarized_thread );
			$self->diag($summarized_thread->message_id . " is now out of date") if !$was_out_of_date and $existing->extra->{out_of_date};
		} else {
			$list->add_threads( $summarized_thread );
		}
	});

	$self->diag( "found threads in the mailing lists: @{[ map { $_->name } values %lists ]}" );

	$summary->save( $summary_out );
}

sub diag {
	my ( $self, @message ) = @_;
	return unless $self->{verbose};
	my $message = "@message";
	chomp $message;
	warn "$message\n";
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
	--update                    Update an existing summary (when the mailbox has new messages)
	--from=DATE                 Something that Date::Manip can parse ('june 1', etc)
	--to=DATE                   like --from
	--list=name                 Only messages for a mailing list by that name.
	--posters                   Extract all posters in a thread
	--dates                     Extract dates from the thread
	--clean                     Try to clean the subject line.

=head1 DESCRIPTION

=cut


