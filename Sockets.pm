##############################################################################
#
#  socket io utilities
#  Vladi Belperchinov-Shabanski "Cade" <cade@biscom.net> <cade@datamax.bg>
#
##############################################################################
package Sockets;
use Exporter;
use strict;
use IO::Select;
use Time::HiRes qw( sleep time );

our @ISA    = qw( Exporter );
our @EXPORT = qw(
                  socket_read
                  socket_write
                  socket_print

                  socket_read_message
                  socket_write_message
                );

##############################################################################

sub socket_read
{
   my $sock    = shift;
   my $data    = shift;
   my $readlen = shift;
   my $timeout = shift || undef;
   
   my $stime = time();

   my $iosel = IO::Select->new();
   $iosel->add( $sock );
   
   my $rlen = $readlen;
   while( $rlen > 0 )
     {
     my @ready = $iosel->can_read( $timeout );
     return undef if @ready == 0 or ( $timeout > 0 and time() - $stime > $timeout );
     
     my $part;
     my $plen = $sock->sysread( $part, $rlen );
     
     return undef if $plen <= 0;
     
     $$data .= $part;
     $rlen  -= $plen;
     }

  return $readlen - $rlen;
}


sub socket_write
{
   my $sock     = shift;
   my $data     = shift;
   my $writelen = shift;
   my $timeout  = shift || undef;
   
   my $stime = time();

   my $iosel = IO::Select->new();
   $iosel->add( $sock );
   
   my $wpos = 0;
   while( $wpos < $writelen )
     {
     my @ready = $iosel->can_write( $timeout );
     return undef if @ready == 0 or ( $timeout > 0 and time() - $stime > $timeout );
 
     my $part;
     my $plen = $sock->syswrite( $data, $writelen - $wpos, $wpos );
     
     return undef if $plen <= 0;
     
     $wpos += $plen;
     }
   
  return $wpos;
}

sub socket_print
{
   my $sock     = shift;
   my $data     = shift;
   my $timeout  = shift || undef;
   
   socket_write( $sock, $data, length( $data ), $timeout );
}

##############################################################################

sub socket_read_message
{
  my $sock = shift;
   
  my $data_len_hex;
  my $rc_data_len = socket_read( $sock, \$data_len_hex, 8 );
  if( $rc_data_len == 0 )
    {
    print( "debug: end of communication channel\n" );
    return undef;
    }
  my $data_len = hex( $data_len_hex );  
  if( $rc_data_len != 8 or $data_len < 0 or $data_len > 999_999_999 )
    {
    print( "fatal: invalid length received, got data length [$rc_data_len], expected 8\n" );
    return undef;
    }
  if( $data_len == 0 )
    {
    socket_write( $sock, '0' x 8, 8 );
    next;
    }

  my $freezed_data;
  my $freezed_data_len = socket_read( $sock, \$freezed_data, $data_len );
  # TODO: check len
  
  my $data = thaw( $freezed_data ); 
  
  return $data ? $data : undef;
}

sub socket_write_message
{
  my $sock = shift;
  my $data = shift;
  
  my $freezed_data = nfreeze( $data );
  $data_len = length( $freezed_data );
  
  $data_len_hex = sprintf( "%08X", $data_len );
  # TODO: check len

  socket_write( $sock, $data_len_hex . $freezed_data, $data_len + 8 );

  return 1;
}


##############################################################################

1;
