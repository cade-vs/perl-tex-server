#!/usr/bin/perl
##############################################################################
#
#  TEX services client
#  Vladi Belperchinov-Shabanski "Cade" <cade@biscom.net> <cade@datamax.bg>
#
##############################################################################
use strict;
use Sockets;
use IO::Socket::INET;

my $tex_file = shift;
my $pdf_file = shift;

my $server_host = shift() || 'localhost:6099';
my $SERVER = IO::Socket::INET->new( PeerAddr => $server_host ) or die "fatal: cannot connect to [$server_host] ($!)\n";

my $data_out = {};
my $data_in  = {};

$data_out->{ 'TEX_DATA' } = file_load( $tex_file );

socket_write_message( $SERVER, $data_out );
$data_in = socket_read_message( $SERVER );

my $pdf_data = $data_in->{ 'PDF_DATA' };
die "empty response\n" unless $pdf_data ne '';

file_save( $pdf_file, $pdf_data );
