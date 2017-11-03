use strict;
use feature 'state';
use IO::Handle;
use Imager;
use List::Util;
use Time::HiRes qw/sleep time/;
use OpenGL qw/ :all /;
use OpenGL::Config;

STDOUT->autoflush(1);

BEGIN
{
    our $WinID;
    our $HEIGHT = 500;
    our $WIDTH  = 500;
    our ($rx, $ry, $rz) = (0.0, 0.0, 0.0);
    our $k_threshold = 10.0;
    our $index = 0;
}

INIT:
{
    ' Load picture ';

    my $file = "../sample.jpg"; 
    our $img = Imager->new();
    our ($H, $W);
    
    $img->read(file=>$file) or die "Cannot load image: ", $img->errstr;
    ($H, $W) = ($img->getheight(), $img->getwidth());
    printf "width: %d, height: %d\n", $W, $H;

    our $mat = [[]];
    our @verts;
    our @colors;
    our $vtx_n = $W * $H;
    our $hash;
    our @sort_key;

    load_pixels($img, $W, $H);
    #only get list in once
    our $verts  = OpenGL::Array->new_list( GL_FLOAT, @verts );
    our $colors = OpenGL::Array->new_list( GL_FLOAT, @colors );
    our @edges;

    our @tg;
    # 频率最高的颜色
    our @points;

    sub high_freq_points
    {
        our (@tg, @points, $k_threshold, $index );
        my ($sum, $x, $y);
        @tg = split( " ", $sort_key[ $index ] );
        @points = ();

        for $y ( 0..$H-1 )
        {
            for my $x ( 0..$W-1 )
            {
                $sum = sqrt(($mat->[$y][$x][0]-$tg[0])**2 + ($mat->[$y][$x][1]-$tg[1])**2 + ($mat->[$y][$x][2]-$tg[2])**2);
                if ( $sum <= $k_threshold )
                {
                    push @points, [ $x, $H-$y, 1.0 ];
                }
            }
        }
    }
}

&main();

sub display
{
    our ($H, $W, $verts, $colors, $vtx_n, @points);

    state $xi = 0.0;
    state $yi = $H/2.0;
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glPointSize(1.0);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);

    # 分量，类型，间隔，指针
    glVertexPointer_c(3, GL_FLOAT, 0, $verts->ptr);
    glColorPointer_c( 3, GL_FLOAT, 0, $colors->ptr);

    #类型，偏移，顶点个数
    glDrawArrays( GL_POINTS, 0, $vtx_n );
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);

    glBegin(GL_POINTS);
    glColor4f(1.0, 0.0, 0.0, 0.3);
    for my $p ( @points )
    {
        glVertex3f( @$p );
    }
    glEnd();

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
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glPointSize(1.0);
}

sub reshape
{
    my ($w, $h) = (shift, shift);
    state $vthalf = 500.0;
    state $hzhalf = 500.0;
    state $fa = 100.0;

    glViewport(0, 0, $w, $h);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho( 0.0, $hzhalf, 0.0, $vthalf, 0.0, $fa*2.0); 
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(0.0,0.0,$fa, 0.0,0.0,0.0, 0.0,1.0, $fa);
}

sub hitkey
{
    our ($WinID, $k_threshold, $index);
    my $k = lc(chr(shift));
    if ( $k eq 'q') { quit() }
    if ( $k eq '-') { $k_threshold -= 1.0; high_freq_points() }
    if ( $k eq '=') { $k_threshold += 1.0; high_freq_points() }
    if ( $k eq '[') { $index -= 1; high_freq_points() }
    if ( $k eq ']') { $index += 1; high_freq_points() }
    printf("%d %.2f\n", $index, $k_threshold );
}

sub quit
{
    our $WinID;
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
    $WinID = glutCreateWindow("DrawArrays");
    
    &init();
    glutDisplayFunc(\&display);
    glutReshapeFunc(\&reshape);
    glutKeyboardFunc(\&hitkey);
    glutIdleFunc(\&idle);
    glutMainLoop();
}

sub load_pixels
{
    our ($mat, $hash, @sort_key);

    my ($img, $W, $H) = @_;
    my ($R, $G, $B, $y, $x);
    my @rgba_arr;

    our @colors;
    our @verts;
    @colors = ();
    @verts = ();

    for $y ( 0 .. $H-1 )
    {
        @rgba_arr = $img->getscanline(y=>$y);
        for $x ( 0 .. $W-1 )
        {
            ($R, $G, $B) = ($rgba_arr[$x]->rgba)[0,1,2];
            push @colors, $R/255.0, $G/255.0, $B/255.0;
            push @verts, ( $x, $H-$y, 0.0 );
            $mat->[$y][$x] = [$R, $G, $B];

            $hash->{"$R $G $B"} += 1;    
        }
    }

    @sort_key = sort { $hash->{$a} <=> $hash->{$a} || $a cmp $b  } keys %$hash;

    print $sort_key[0] ,"\n";
    print $sort_key[-1] ,"\n";

    for my $k ( @sort_key )
    {
        printf "%-12s %d\n", $k, $hash->{$k};
    }
}