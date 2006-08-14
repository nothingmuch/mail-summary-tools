#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'Mail::Summary::Tools::FlatFile';

use Mail::Summary::Tools::Summary;

my $summary = Mail::Summary::Tools::Summary->new(
	lists => [
		Mail::Summary::Tools::Summary::List->new(
			name => "list1",
			threads => [
				my $droppings = Mail::Summary::Tools::Summary::Thread->new(
					message_id => 'unique1@example.com',
					subject => "Moose droppings",
					extra => {
						posters => [ { name => "User 1", email => 'foo@example.com' } ],
					},
					default_archive => "gmane",
				),
				my $drool = Mail::Summary::Tools::Summary::Thread->new(
					message_id => 'unique2@example.com',
					subject => "Moose drool",
					default_archive => "gmane",
				),
			],
		),
		Mail::Summary::Tools::Summary::List->new(
			name => "list2",
			threads => [
				my $nuts = Mail::Summary::Tools::Summary::Thread->new(
					message_id => 'unique3@example.com',
					subject => "Moose nuts",
					default_archive => "gmane",
					summary => "third_orig",
				),
			],
		),
	],
);

my $flat = Mail::Summary::Tools::FlatFile->new( summary => $summary );

my $text = do { local $/; <DATA> };

$flat->load( $text );

is( $droppings->summary, 
q{Summary la la la

new paragraph


double space},
"thread 1 summary" );

is( $drool->summary, "Foo", "thread 2 summary" );

is( $nuts->summary, "third", "thread 3 summary" );

is( $nuts->subject, "Moose <censored>", "subject changed" );

isa_ok( $nuts->archive_link, "Mail::Summary::Tools::ArchiveLink::Hardcoded" );

__DATA__
message_id: unique1@example.com

4Q#$!%!% garbaagae1
432oiu3hkjahtr
ignored

Summary la la la

new paragraph


double space

---

message_id: unique2@example.com
subject: Moose drool

<http://news.gmane.org/find-root.php?message_id=%3Cunique2%40example.com%3E>

Foo
---

message_id: unique3@example.com
subject: Moose <censored>
thread_uri: http://custom/

blah

third
---


