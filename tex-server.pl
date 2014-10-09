#!/usr/bin/perl
##############################################################################
#
#  TEX services server
#  Vladi Belperchinov-Shabanski "Cade" <cade@biscom.net> <cade@datamax.bg>
#
##############################################################################
use strict;
use POSIX ":sys_wait_h";
use Socket;
use IO::Socket;
use IO::Socket::INET;
use Data::Tools;
use Sockets;

my $break_main_loop = 0;

##############################################################################

my $LISTEN_PORT = 6099;

##############################################################################

$SIG{ 'INT'  } = sub { $break_main_loop = 1; };
$SIG{ 'CHLD' } = \&child_sub;

my $SERVER;

$SERVER = IO::Socket::INET->new( Proto     => 'tcp',
                                 LocalPort => $LISTEN_PORT,
                                 Listen    => 128,
                                 ReuseAddr => 1,
                                 );

if( ! $SERVER )
  {
  print( "fatal: cannot open server port $LISTEN_PORT: $!\n" );
  exit 10;
  }
else
  {
  print( "status: listening on port $LISTEN_PORT" );
  }

while(4)
  {
  last if $break_main_loop;
  my $CLIENT = $SERVER->accept();
  if( ! $CLIENT )
    {
    next;
    }

  my $peerhost = $CLIENT->peerhost();
  my $peerport = $CLIENT->peerport();
  my $sockhost = $CLIENT->sockhost();
  my $sockport = $CLIENT->sockport();

  print( "info: connection from $peerhost:$peerport to me at $sockhost:$sockport\n" );

  my $pid;

  $pid = fork();
  if( ! defined $pid )
    {
    die "fatal: fork failed: $!";
    }
  if( $pid )
    {
    # parent here, next
    print( "status: new process forked with pid [$pid]\n" );
    next;
    }

  # kid here

  # reinstall signal handlers in the kid
  $SIG{ 'INT'  } = sub { $break_main_loop = 1; };
  $SIG{ 'CHLD' } = 'DEFAULT';

  print( "status: client connected from [$peerhost:$peerport]\n" );
  $CLIENT->autoflush(1);
  eval
    {
    process_tex_request( $CLIENT );
    };
  if( $@ )  
    {
    print "error: process tex failed: $@\n";
    }
  $CLIENT->close();
  
  print( "status: client disconnected from [$peerhost:$peerport]\n" );
  exit();
  }
close( $SERVER );

##############################################################################

sub child_sub
{
  my $kid;
  while( ( $kid = waitpid( -1, WNOHANG ) ) > 0 )
    {
    print( "status: sigchld received [$kid]\n" );
    }
  $SIG{ 'CHLD' } = \&child_sub;
}

##############################################################################

sub process_tex_request
{
  my $CLIENT = shift;

  my $data = socket_read_message( $CLIENT );
  
  my $tex_data = $data->{ 'TEX_DATA' };
  
  my $tex_file = "tmp.$$.tex";
  my $pdf_file = "tmp.$$.pdf";

  file_save( $tex_file, $tex_data );
  my $cmd = "pdflatex -interaction=nonstopmode -jobname=tmp.$$ $tex_file";
  print "executing: [$cmd]\n";
  system( $cmd );
  # TODO: check result

  my $data_out = {};
  
  $data_out->{ 'PDF_DATA' } = file_load( $pdf_file );
  
  unlink( "tmp.$$.aux" );
  unlink( "tmp.$$.log" );
  unlink( "tmp.$$.tex" );
  unlink( "tmp.$$.pdf" );
  
  socket_write_message( $CLIENT, $data_out );
}

###EOF########################################################################

