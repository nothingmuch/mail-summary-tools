#!/usr/bin/perl

package Mail::Summary::Tools::CLI::ToText;
use base qw/App::CLI::Command/;

use strict;
use warnings;

use Mail::Summary::Tools::Summary;
use Mail::Summary::Tools::Output::TT;

use Text::Wrap ();

use constant options => (
	'v|verbose'       => "verbose",
    'shorten:s'       => 'shorten',
    's'               => 'shorten_bool',
    'i|input=s'       => 'input',    # required, string
    'o|output:s'      => 'output',   # defaults to '-'
    'a|archive:s'     => 'archive',  # defaults to 'google'
    't|template:s'    => 'template', # defaults to '', which means __DATA__
    'c|columns:i'     => 'columns',  # defaults to 80
    'w|wrap_overflow' => 'wrap_overflow', # whether or not to force wrapping of overflowing text
);

sub wrap {
    my ( $self, $text, $columns, $first_indent, $rest_indent ) = @_;

    $columns ||= $self->{columns} || 80;
    $first_indent ||= '    ';
    $rest_indent  ||= '    ';

    no warnings 'once';
    local $Text::Wrap::huge = $self->_wrap_huge;
    local $Text::Wrap::columns = $columns;

	$text =~ s/\\(\S)/$1/g; # unquotemeta

    Text::Wrap::fill( $first_indent, $rest_indent, $self->process_body($text) );
}

sub process_body {
	my ( $self, $text ) = @_;

	$text =~ s/<(\w+:\S+?)>/$self->expand_uri($1)/ge;
	$text =~ s/\[(.*?)\]\((\w+:\S+?)\)/$self->expand_uri($2, $1)/ge;

	return $text;
}

sub bullet {
    my ( $self, $text, $columns ) = @_;
    $self->wrap( $text, $columns, '  * ', '    ' );
}

sub heading {
    my ( $self, $text, $columns ) = @_;
    $self->wrap( $text, $columns, '  ', '  ' );
}

sub _wrap_huge {
    my $self = shift;
    return $self->{wrap_overflow} ? 'wrap' : 'overflow'; # default to not breaking URIs
}

sub shorten {
    my ( $self, $uri ) = @_;

	if ( $self->should_shorten($uri) ) {
		$self->really_shorten( $uri );
	} else {
		return $uri;
	}
}

sub rt_uri {
	my ( $self, $rt, $id ) = @_;

	if ( $rt eq "perl" ) {
		return $self->shorten("http://rt.perl.org/rt3/Ticket/Display.html?id=$id");
	} else {
		die "unknown rt installation: $rt";
	}
}

sub link_to_message {
	my ( $self, $message_id, $text ) = @_;

	my $thread = $self->{__summary}->get_thread_by_id( $message_id ) || die "$message_id is not in summary";

	my $uri = $self->shorten($thread->archive_link->thread_uri);
	
	$text ||= $thread->subject;

	"$text <$uri>";
}

sub expand_uri {
	my ( $self, $uri_string, $text ) = @_;

	my $uri = URI->new($uri_string);

	if ( $uri->scheme eq 'rt' ) {
		my ( $rt, $id ) = ( $uri->authority, substr($uri->path, 1) );
	   	my $rt_uri = $self->rt_uri($rt, $id);
		$text ||= "[$rt #$id]";
		return "$text <$rt_uri>";
	} elsif ( $uri->scheme eq 'msgid' ) {
		return $self->link_to_message( join("", grep { defined } $uri->authority, $uri->path), $text );
	} else {
		my $short_uri = $self->shorten($uri) || $uri;
		return $text ? "$text <$short_uri>" : "<$short_uri>";
	}
}

sub really_shorten {
    my ( $self, $uri ) = @_;
    
    my $service = $self->{shorten};

	my $cache = $self->{context}->cache;

	my $cache_key = join(":", "shorten", $service, $uri);

	if ( my $short = $cache->get($cache_key) ) {
		return $short;
	} else {
		my $mod = "WWW::Shorten::$service";
		unless ( $mod->can("makeashorterlink") ) {
			my $file = join("/", split("::", $mod ) ) . ".pm";
			require $file;
		}

		no strict 'refs';
		my $short = &{"${mod}::makeashorterlink"}( $uri ) || "$uri";
		$cache->set( $cache_key, $short );
		return $short;
	}
}

sub shortening_enabled {
    my ( $self, $uri ) = @_;
    if ( $self->{shorten} ) {
        return 1;
    } else {
        return;
    }
}

sub should_shorten {
    my ( $self, $uri ) = @_;
    return unless $self->shortening_enabled;

    length($uri) > 40 || $uri =~ /gmane|groups\.google/
}

sub template_input {
    my $self = shift;

    if ( my $file = $self->{template} ) {
        open my $fh, "<", $file or die "Couldn't open template (open($file): $!)\n";
		binmode $fh, ":utf8";
        return $fh;
    } else {
		binmode DATA, ":utf8";
        return \*DATA;
    }
}

sub template_output {
    my $self = shift;
    
    if ( !$self->{output} or $self->{output} eq '-' ) {
		binmode STDOUT, ":utf8";
        return \*STDOUT;
    } elsif ( my $file = $self->{output} ) {
        open my $fh, ">", $file or die "Couldn't open output (open($file): $!)\n";
		binmode $fh, ":utf8";
        return $fh;
    }
}

sub run {
    my ( $self, @args ) = @_;
	@args and $self->{$_} ||= shift @args for qw/input output/;

	$self->{shorten} ||= "Metamark" if $self->{shorten_bool};

    my $summary = Mail::Summary::Tools::Summary->load(
        $self->{input} || die("You must supply a summary YAML file to textify.\n"),
        thread => {
            default_archive => $self->{archive} || "google",
			archive_link_params => { cache => $self->{context}->cache },
        },
    );

	my $o = Mail::Summary::Tools::Output::TT->new(
		template_input  => $self->template_input,
		template_output => $self->template_output,
	);

	$o->process(
		$self->{__summary} = $summary, # FIXME Output::Plain
		{
			shorten => sub { $self->shorten(shift) },
			wrap    => sub { $self->wrap(shift) },
			bullet  => sub { $self->bullet(shift) },
			heading => sub { $self->heading(shift) },
		},
	);
}

__PACKAGE__;

=pod

=head1 USAGE

	totext --shorten --input summary.yaml

=head1 OPTIONS

	--verbose                   Not yet implemented.
	--input=FILE.yml            Which summary to process
	--output                    Where to output. Defaults to '-', which is stdout.
	--archive=SERVICE           Which archival service to link to. "google" or "gmane".
	--shorten[=SERVICE]         Shorten long URIs in the text output. You can
	                            specify a WWW::Shorten service. The short form (-s)
	                            accepts no arguments, and defaults to xrl.us
	--template=FILE             Use this template instead of the deafult one 
	--columns=NCOLS             For text wrapping. Defaults to 80.
	--wrap_overflow             Whether or not to force wrapping of overflowing text.

=cut

__DATA__
[% summary.title %]

[% IF summary.extra.header %][% FOREACH section IN summary.extra.header %] [% heading(section.title) %]

[% wrap(section.body) %]
[% END %]
[% END %][% FOREACH list IN summary.lists %]
 [% list.title %]
[% IF list.extra.description %]
[% wrap(list.extra.description) %]
[% END %][% FOREACH thread IN list.threads %][% IF thread.hidden %][% NEXT %][% END %]
[% head = BLOCK %][% thread.subject %] <[% shorten(thread.archive_link.thread_uri) %]>[% END %][% heading(head) %]

[% IF thread.summary %][% wrap(thread.summary) %]
[% ELSE %]    Posters:[% FOREACH participant IN thread.extra.posters %]
    - [% participant.name %][% END %]
[% END %][% END %][% END %]
[% IF summary.extra.footer %][% FOREACH section IN summary.extra.footer %] [% heading(section.title) %]

[% wrap(section.body) %]
[% END %]
[% END %][% IF summary.extra.see_also %] See Also
[% FOREACH item IN summary.extra.see_also %]
[% link = BLOCK %][% item.name %] <[% shorten(item.uri ) %]>[% END %][% bullet(link) %]
[% END %]
[% END %]
