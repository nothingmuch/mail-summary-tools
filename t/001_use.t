#!/usr/bin/perl

use strict;
use warnings;

use Test::More 'no_plan';

use ok 'Mail::Summary::Tools';

use ok 'Mail::Summary::Tools::ArchiveLink::Easy';
use ok 'Mail::Summary::Tools::ArchiveLink::GoogleGroups';
use ok 'Mail::Summary::Tools::ArchiveLink::Gmane';

use ok 'Mail::Summary::Tools::Summary';
use ok 'Mail::Summary::Tools::Summary::List';
use ok 'Mail::Summary::Tools::Summary::Thread';

use ok 'Mail::Summary::Tools::ThreadLoader';
use ok 'Mail::Summary::Tools::ThreadFilter';
use ok 'Mail::Summary::Tools::ThreadFilter::Util';

use ok 'Mail::Summary::Tools::Output::TT';


