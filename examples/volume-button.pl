#!/usr/bin/perl

use Gtk2 -init;
use Gtk2::Ex::VolumeButton;

my $w = Gtk2::Window->new();
my $b = Gtk2::VBox->new();
my $v = Gtk2::Ex::VolumeButton->new(
		zero_image		=> 'gtk-quit',
		min_image		=> 'gtk-ok',
		medium_image	=> 'gtk-quit',
		max_image		=> 'gtk-ok'
);

$b->pack_start($v, 1, 1, 0);
$w->add($b);
$w->show_all();

Gtk2->main();
