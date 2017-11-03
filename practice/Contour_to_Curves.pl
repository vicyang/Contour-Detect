use strict;
use utf8;
use Encode;
use feature 'state';
use List::Util qw/sum max min/;
use Data::Dumper;
use File::Slurp;
use Time::HiRes qw/sleep time/;

use OpenGL qw/ :all /;
use OpenGL::Config;
use IO::Handle;
STDOUT->autoflush(1);

BEGIN
{
    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 500;
    our $show_w = 500;
    our $show_h = 500;

    our ($rx, $ry, $rz) = (0.0, 0.0, 0.0);
    our $k_threshold = 20.0;
    our $d_threshold = 50.0;
}

INIT:
{
    ' Load curves ';
    my $str = read_file( "contour.svg" ) or die $!;
    our @points;
    my ($x, $y);

    if ($str =~ /points="([^"]+)"/)
    {
        #@points = map { [ split(",", $_), 0.0 ] } 
        grep {
            ($x, $y) = (split ",", $_);
            push @points, [$x, 500.0-$y, 0.0];
        } split(" ", $1);
    }
    else
    {
        warn "something wrong !\n";
    }
}

&main();

sub display
{
    our (@points);
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glBegin(GL_POINTS);
    for my $e ( 0 .. $#points )
    {
        glColor3f( 1.0-$e/($#points+1), $e/($#points+1), 0.6 ); ' +1 防止除0错误';
        glVertex3f( @{$points[$e]} );
    }
    glEnd();
    # printf "x:%d : %.2f %.2f %.2f\n", $xi, @{$mat->[$yi][$xi]};

    glutSwapBuffers();
}

sub idle 
{
    state $ta;
    state $tb;

    $ta = time();
    sleep 0.02;

    display();

    $tb = time();
    #printf "%.4f\n", $tb-$ta;
}

sub init
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glEnable(GL_DEPTH_TEST);
    glPointSize(1.0);
    glLineWidth(1.0);
}

sub reshape
{
    our ($H, $W);
    state $fa = 100.0;
    my ($w, $h) = (shift, shift);
    my $w_min = min( $h, $w );

    glViewport(0, 0, $w_min, $w_min);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho( 0.0, 500.0, 0.0, 500.0, 0.0, $fa*2.0); 
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(0.0,0.0,$fa, 0.0,0.0,0.0, 0.0,1.0, $fa);
}

sub hitkey
{
    our ($WinID, $k_threshold, $d_threshold);
    my $k = lc(chr(shift));
    if ( $k eq 'q') { quit() }
    if ( $k eq '-') { $k_threshold -= 1.0; scan_edge() }
    if ( $k eq '=') { $k_threshold += 1.0; scan_edge() }
    if ( $k eq '[') { $d_threshold -= 1.0; scan_edge() }
    if ( $k eq ']') { $d_threshold += 1.0; scan_edge() }
    printf("%.2f %.2f\n", $k_threshold, $d_threshold);
}

sub quit
{
    our ($WinID);
    glutDestroyWindow( $WinID );
    exit 0;
}

sub main
{
    our ($MAIN, $WIDTH, $HEIGHT, $WinID);

    glutInit();
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH | GLUT_MULTISAMPLE );
    glutInitWindowSize($WIDTH, $HEIGHT);
    glutInitWindowPosition(100, 100);
    $WinID = glutCreateWindow("Detect Contour");
    
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}

sub export_svg
{
    our ($H);
    my $pts = shift;
    my $head = '<svg width="100%" height="100%" version="1.1" xmlns="http://www.w3.org/2000/svg">';
    my $body = '<polyline points="';

    for my $i ( 0 .. $#$pts )
    {
        $body .= sprintf "%d,%d ", $pts->[$i][0], $H - $pts->[$i][1];
    }
    $body .= '" style="fill:none;stroke:red;stroke-width:2"/>';

    my $end = '</svg>';

    write_file("contour.svg", join("\n", $head, $body, $end) );
}
