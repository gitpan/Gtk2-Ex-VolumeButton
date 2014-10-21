package Gtk2::Ex::VolumeButton;

use strict;
use warnings;
use Glib qw( TRUE FALSE );
use Gtk2;
use Gtk2::Gdk::Keysyms;

our $VERSION = '0.02';

use Glib::Object::Subclass
	Gtk2::ToggleButton::,
	signals => {
		volume_changed => {
			flags			=> [qw( run-last )],
			return_type		=> undef,
			param_types		=> [qw( Glib::Int  )]
		},
		show => \&on_show
	},
	properties => [
		Glib::ParamSpec->int(
				'volume',
				'Volume',
				'Current volume',
				0,
				100,
				50,
				[qw( readable writable )]
		),
		Glib::ParamSpec->string(
				'zero_image',
				'Zero Image',
				'Image to display when the volume is zero',
				'',
				[qw( readable writable )]
		),
		Glib::ParamSpec->string(
				'min_image',
				'Min Image',
				'Image to display when the volume is minimal',
				'',
				[qw( readable writable )]
		),
		Glib::ParamSpec->string(
				'medium_image',
				'Medium Image',
				'Image to display when the volume is medium',
				'',
				[qw( readable writable )]
		),
		Glib::ParamSpec->string(
				'max_image',
				'Max Image',
				'Image to display when the volume is maximal',
				'',
				[qw( readable writable )]
		)
	];

sub INIT_INSTANCE {
	my $self = shift;

	$self->{volume} = 0;
	
	$self->signal_connect( 'toggled', \&toggle_cb );
	$self->signal_connect( 'scroll_event', \&scroll_event_cb );
	
#	if( -r $self->{min_image} ) {
#		$self->{image} = Gtk2::Image->new_from_file( $self->{min_image} );
#	} elsif( ref $self->{min_image} eq 'Gtk2::Gdk::Pixbuf' ) {
#		$self->{image} = Gtk2::Image->new_from_pixbuf( $self->{min_image} );
#	} else {
#		$self->{image} = Gtk2::Image->new_from_stock( $self->{min_image} );
#	}
	$self->{image} = Gtk2::Image->new();
	$self->{image}->show();
	$self->add( $self->{image} );
}

sub on_show {
	my $self = shift;
	$self->update_image( $self->{volume} );
	$self->signal_chain_from_overridden();
}

sub _CLAMP {
	my( $x, $min, $max ) = @_;

	return $max if $x > $max;
	return $min if $x < $min;
	return $x;
}

sub _MAX {
	my( $a, $b ) = @_;

	return ($a > $b) ? $a : $b;
}

sub scale_key_press_cb {
	my( undef, $event, $self ) = @_;

	if( $event->keyval == $Gtk2::Gdk::Keysyms{Escape} ) {
		$self->hide_scale();
		$self->set_volume( $self->{revert_volume} );
		return TRUE;
	} elsif($event->keyval == $Gtk2::Gdk::Keysyms{Return} ||
			$event->keyval == $Gtk2::Gdk::Keysyms{space} ) {
		$self->hide_scale();
		return TRUE;
	}

	return FALSE;
}

sub scale_value_changed_cb {
	my( $widget, $self ) = @_;
	
	my $vol = $widget->get_value();
	$vol = _CLAMP( $vol, 0, 100 );

	$self->{volume} = $vol;
	$self->update_image($vol);

	$self->signal_emit( 'volume_changed', $vol );
}

sub popup_button_press_event_cb {
	my( undef, undef, $self ) = @_;
	
	if( $self->{popup} ) {
		$self->hide_scale();
		return TRUE;
	}

	return FALSE;
}

sub show_scale {
	my $self = shift;

	$self->{popup} = Gtk2::Window->new('popup');
	$self->{popup}->set_screen( $self->get_screen );

	$self->{revert_volume} = $self->{volume};

	my $frame = Gtk2::Frame->new();
	$frame->set_border_width(0);
	$frame->set_shadow_type('out');
	$frame->show();

	$self->{popup}->add($frame);

	my $box = Gtk2::VBox->new( FALSE, 0 );
	$box->show();

	$frame->add($box);

	my $adj = Gtk2::Adjustment->new( $self->{volume}, 0, 100, 5, 10, 0 );
	$self->{scale} = Gtk2::VScale->new($adj);
	$self->{scale}->set_draw_value(FALSE);
	$self->{scale}->set_update_policy('continuous');
	$self->{scale}->set_inverted(TRUE);
	$self->{scale}->show();

	$self->{popup}->signal_connect( 'button_press_event',
			\&popup_button_press_event_cb, $self);
	$self->{scale}->signal_connect( 'key_press_event', \&scale_key_press_cb,
			$self );
	$self->{scale}->signal_connect( 'value_changed', \&scale_value_changed_cb,
			$self );

	my $label = Gtk2::Label->new('+');
	$label->show();
	$box->pack_start( $label, FALSE, TRUE, 0 );

	$label = Gtk2::Label->new('-');
	$label->show();
	$box->pack_end( $label, FALSE, TRUE, 0 );

	$box->pack_start( $self->{scale}, TRUE, TRUE, 0 );

	my $req = $self->{popup}->size_request();
	my($x, $y) = $self->window->get_origin();
	my $alloc = $self->get_parent->allocation();

	$req->width( _MAX($req->width, $alloc->width) );

	$x += $alloc->x;
	$y += $alloc->y + $alloc->height;

	$x = _MAX( 0, $x );
	$y = _MAX( 0, $y );

	$self->{scale}->set_size_request( -1, 100 );
	$self->{popup}->set_size_request( $req->width, -1 );

	$self->{popup}->move($x, $y);
	$self->{popup}->show();

	$self->{popup}->grab_focus();
	Gtk2->grab_add( $self->{popup} );

	my $grabbed = Gtk2::Gdk->pointer_grab(
			$self->{popup}->window, TRUE,
			[qw( button-press-mask button-release-mask pointer-motion-mask )],
			undef, undef, Gtk2->get_current_event_time() );

	if( $grabbed eq 'success' ) {
		$grabbed = Gtk2::Gdk->keyboard_grab( $self->{popup}->window, TRUE,
				Gtk2->get_current_event_time() );

		$grabbed = 'success';
		unless( $grabbed eq 'success' ) {
			Gtk2->grab_remove( $self->{popup} );
			$self->{popup}->destroy();
		}
	} else {
		Gtk2->grab_remove( $self->{popup} );
		$self->{popup}->destroy();
	}
}

sub hide_scale {
	my $self = shift;

	if( $self->{popup} ) {
		Gtk2->grab_remove( $self->{popup} );
		Gtk2::Gdk->pointer_ungrab( Gtk2->get_current_event_time() );
		Gtk2::Gdk->keyboard_ungrab( Gtk2->get_current_event_time() );
		$self->{popup}->destroy();
	}

	if( $self->get_active() ) {
		$self->set_active(FALSE);
	}
}

sub toggle_cb {
	my $self = shift;

	if( $self->get_active() ) {
		$self->show_scale();
	} else {
		$self->hide_scale();
	}
}

sub scroll_event_cb {
	my($self, $event) = @_;

	my $vol = $self->{volume};

	if( $event->direction eq 'up' ) {
		$vol += 10;
	} elsif( $event->direction eq 'down' ) {
		$vol -= 10;
	} else {
		return;
	}

	$vol = _CLAMP( $vol, 0, 100 );

	$self->set_volume($vol);
	$self->update_image($vol);
	
	return TRUE;
}

sub set_volume {
	my($self, $vol) = @_;

	return if $self->{volume} == $vol;

	$self->{volume} = $vol;
	$self->update_image( $vol );
	$self->signal_emit( 'volume_changed', $vol );
}

sub update_image {
	my($self, $vol) = @_;
	my $id;
	
	if( $vol <= 0 ) {
		$id = 'zero';
	} elsif( $vol <= 100 / 3 ) {
		$id = 'min';
	} elsif( $vol <= 2 * 100 / 3 ) {
		$id = 'medium';
	} else {
		$id = 'max';
	}

	if( ref $self->{$id.'_image'} eq 'Gtk2::Gdk::Pixbuf' ) {
		$self->{image}->set_from_pixbuf( $self->{$id.'_image'} );
	} elsif( -r $self->{$id.'_image'} ) {
		$self->{image}->set_from_file( $self->{$id.'_image'} );
	} else {
		$self->{image}->set_from_stock( $self->{$id.'_image'}, 'button' );
	}
}

1;

__END__
=head1 NAME

Gtk2::Ex::VolumeButton - widget to control volume and similar values

=head1 DESCRIPTION

Gtk2::Ex::VolumeButton is a simple Gtk2 widget based on Gtk2::ToggleButton to
control the volume and similar values. It consists of a Gtk2::ToggleButton
widget displaying an image representing the current volume. When the button is
clicked a popup window containing a Gtk2::VScale widget shows up and allows you
to change the widgets volume value. It's also possible to change the volume
using the scroll wheel over the toggle button even if the popup window isn't
shown.

This widget is modeled after the widgets use in gnome-panel, muine and
rhythmbox. Much code is stolen from the muine volume-button widget.

=head1 OBJECT HIERARCHY

  Glib::Object
  +----Gtk2::Object
        +----Gtk2::Widget
              +----Gtk2::Container
                    +-----Gtk2::Bin
                           +----Gtk2::Button
                                 +----Gtk2::ToggleButton
                                       +----Gtk2::Ex::VolumeButton

=head1 SYNOPSIS

  use Gtk2::Ex::VolumeButton;

  ...

  my $vb = Gtk2::Ex::VolumeButton->new(
      volume       => 20,
      zero_image   => 'zero.png',
      min_image    => 'min.png',
      medium_image => 'medium.png',
      max_image	   => 'max.png'
  );
  $vb->show();

  $vb->signal_connect( volume_changed =>
      sub { print 'volume changed: ', $vb->{volume}, "\n" } );

  ...

  Gtk2->main();

=head1 PROPERTIES

=over 4

=item 'volume' (int : readable / writable)

Current volume

=item 'zero_image' (string : readable / writable)

Image to display when the volume is zero

=item 'min_image' (string : readable / writable)

Image to display when the volume is minimal

=item 'medium_image' (string : readable / writable)

Image to display when the volume is medium

=item 'max_image' (string : readable / writable)

Image to display when the volume is maximal

=back

=head1 SIGNALS

=over 4

=item 'volume_changed'

Emitted when the volume property is changed

=back

=head1 SEE ALSO

L<Gtk2>, L<Glib::Object>, L<Gtk2::Object>, L<Gtk2::Widget>, L<Gtk2::Container>,
L<Gtk2::Bin>, L<Gtk2::Button>, L<Gtk2::ToggleButton>

=head1 AUTHOR

Florian Ragwitz E<lt>flora@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Florian Ragwitz

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Library General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut
