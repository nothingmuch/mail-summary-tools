#!/usr/bin/perl

package Mail::Summary::Tools::Output::HTML;
use Moose;

use utf8;

use Mail::Summary::Tools::Output::TT;
use Text::Markdown ();

has summary => (
	isa => "Mail::Summary::Tools::Summary",
	is  => "rw",
	required => 1,
);

has description => (
	isa => "Str",
	is  => "rw",
	default => "Mailing list summary",
);

has generator => (
	isa  => "Str",
	is   => "rw",
	lazy => 1,
	default => sub {
		my $self = shift;
		require Mail::Summary::Tools;
		return __PACKAGE__ . " version $Mail::Summary::Tools::VERSION";
	},
);

has template_config => (
	isa => "HashRef",
	is  => "rw",
	default => sub { return {} },
);

has template_obj => (
	isa => "Template",
	is  => "rw",
	lazy => 1,
	default => sub { Template->new( $_[0]->template_config ) },
);

sub process {
	my $self = shift;

	print $self->template_snippet(
		$self->main_template,
		html => $self,
		markdown => sub { $self->markdown(@_) },
	);
}

sub template_snippet {
	my ( $self, $snippet, %vars ) = @_;
	
	my $out;	

	my $tt = $self->template_obj;

	$tt->process(
		\$snippet,
		{
			%vars,
			html => $self,
		},
		\$out,		
	) || warn $tt->error . " in $snippet";

	return $out;
}

sub markdown {
	my ( $self, $text ) = @_;

	$text =~ s/<(\w+:.*?)>/$self->expand_uri($1)/ge;

	Text::Markdown::markdown($text);
}

sub rt_uri {
	my ( $self, $rt, $id ) = @_;
	
	if ( $rt eq "perl" ) {
		return "http://rt.perl.org/rt3/Public/Bug/Display.html?id=$id";
	} else {
		die "unknown rt installation: $rt";
	}
}

sub link_to_message {
	my ( $self, $message_id ) = @_;

	# FIXME
	# hidden threads, etc

	require Mail::Summary::Tools::ArchiveLink::GoogleGroups;
	my $uri = Mail::Summary::Tools::ArchiveLink::GoogleGroups->new( message_id => $message_id )->thread_uri;

	"[another thread]($uri)"
}

sub expand_uri {
	my ( $self, $uri_text ) = @_;

	my $uri = URI->new($uri_text);

	if ( $uri->scheme eq 'rt' ) {
		my ( $rt, $id ) = ( $uri->authority, substr($uri->path, 1) );
	   	my $rt_uri = $self->rt_uri($rt, $id);
		return "[[$rt #$id]]($rt_uri)";
	} elsif ( $uri->scheme eq 'msgid' ) {
		return $self->link_to_message( join("", grep { defined } $uri->authority, $uri->path) );
	} else {
		return "<$uri>"; # markdown will auto linkfy
	}
}

sub toc {
	my $self = shift;
	return ();
}

sub body {
	my $self = shift;

	return join("\n\n\n",
		$self->header,
		$self->lists,
		$self->footer,
	);
}

sub header {
	my $self = shift;
	$self->template_snippet(
		$self->header_template,
		title => $self->summary->title,
	);
}

use constant header_template => <<'TMPL';
<h1>[% title | html %]</h1>
TMPL

sub footer {
	my $self = shift;
	return join("\n\n",
		$self->custom_footer,
		$self->see_also,
	);
}

sub custom_footer {
	my $self = shift;

	if ( my $footer = $self->summary->extra->{footer} ) {
		return join("\n\n", map { $self->custom_footer_section( $_ ) } @$footer );
	} else {
		return ();
	}
}

sub custom_footer_section {
	my ( $self, $section ) = @_;
	$self->template_snippet(
		$self->custom_footer_section_template,
		section => $section,
	);
}

use constant custom_footer_section_template => <<'TMPL';
<h2>[% section.title | html %]</h2>

[% markdown(section.body) %]
TMPL

sub see_also {
	my $self = shift;

	if ( my $see_also = $self->summary->extra->{see_also} ) {
		$self->template_snippet(
			$self->see_also_template,
			items => $see_also,
		);
	} else {
		return ();
	}
}

use constant see_also_template => <<'TMPL';
<h2>See Also</h2>

<ul>
[% FOREACH item IN items %]<li><a href="[% item.uri | html %]">[% item.name %]</a></li>[% END %]
</ul>
TMPL

sub lists {
	my $self = shift;
	
	return join("\n\n\n", map { $self->list($_) } $self->summary->lists );
}

sub list {
	my ( $self, $list ) = @_;

	return join("\n\n",
		$self->list_header($list),
		$self->list_body($list),
		$self->list_footer($list),
	);
}

sub list_header {
	my ( $self, $list ) = @_;
	$self->template_snippet( $self->list_header_template, list => $list );
}

use constant list_header_template => <<'TMPL';
<h2>[% IF list.url %]<a href="[% list.url | html %]">[% END %][% list.title | html %][% IF list.url %]</a>[% END %]</h2>
[% IF list.extra.description %]
[% markdown(list.extra.description) %]
[% END %]
TMPL

sub list_body {
	my ( $self, $list ) = @_;
	return join("\n\n", map { $self->thread($_) } $list->threads );
}

sub list_footer {
	my ( $self, $list ) = @_;
	return ();
}

sub thread {
	my ( $self, $thread ) = @_;
	return join("\n\n",
		$self->thread_header($thread),
		$self->thread_body($thread),
		$self->thread_footer($thread),
	);
}

sub thread_header {
	my ( $self, $thread ) = @_;
	$self->template_snippet( $self->thread_header_template, thread => $thread );
}

use constant thread_header_template => <<'TMPL';
<h3><a href="[% thread.archive_link.thread_uri | html %]">[% thread.subject | html %]</a></h3>
TMPL

sub thread_body {
	my ( $self, $thread ) = @_;
	$self->template_snippet( $self->thread_body_template, thread => $thread );
}

use constant thread_body_template => <<'TMPL';
[% IF thread.summary %]
	<p>
		[% markdown(thread.summary) %]
	</p>
[% ELSE %]
	<p>No summary provided.</p>
	[% IF thread.extra.posters %]
		<p>The following people participated in this thread:</p>
		<ul>
			[% FOREACH poster IN thread.extra.posters %]<li>[% poster.name | html %]</li>[% END %]
		</ul>
	[% END %]
[% END %]
TMPL

sub thread_footer {
	my ( $self, $thread ) = @_;
	return ();
}

sub css {
	my $self = shift;
	return ();
}

use constant main_template => <<'TMPL';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
	<head>
		<title>[% summary.title | html %]</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta name="description" content="[% html.description | html %]" />
		<meta name="generator" content="[% html.generator | html %]" />
		[% html.css %]
	</head>
	<body>
		[% html.toc %]
		[% html.body %]
	</body>
</html>
TMPL

__PACKAGE__;

__END__

=pod

=head1 NAME

Mail::Summary::Tools::Output::HTML - 

=head1 SYNOPSIS

	use Mail::Summary::Tools::Output::HTML;

=head1 DESCRIPTION

=cut
