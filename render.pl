use feature 'state';
use IO::Handle;
use Imager;
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
}

INIT:
{
    ' Load picture ';

    my $file = "sample.jpg"; 
    our $img = Imager->new();
    our ($H, $W);
    our @cv = (1.0, 2.0, 1.0);
    
    $img->read(file=>$file) or die "Cannot load image: ", $image->errstr;
    ($H, $W) = ($img->getheight(), $img->getwidth());
    printf "width: %d, height: %d\n", $W, $H;

    our @verts;
    our @colors;
    our $vtx_n = $W * $H;

    update();
}

&main();

sub display
{
    our $img2;
    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);
    my $verts  = OpenGL::Array->new_list( GL_FLOAT, @verts );
    my $colors = OpenGL::Array->new_list( GL_FLOAT, @colors );

    # 分量，类型，间隔，指针
    glVertexPointer_c(3, GL_FLOAT, 0, $verts->ptr);
    glColorPointer_c( 3, GL_FLOAT, 0, $colors->ptr);

    #类型，偏移，顶点个数
    glDrawArrays( GL_POINTS, 0, $vtx_n );
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);

    glutSwapBuffers();
}

sub idle 
{
    sleep 0.05;
    glutPostRedisplay();
}

sub init
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glEnable(GL_DEPTH_TEST);
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
    our $WinID;
    my $k = lc(chr(shift));
    if ( $k eq 'q') { quit() }
    if ( $k eq '4') { $cv[0]+=0.2; update(); }
    if ( $k eq '5') { $cv[1]+=0.2; update(); }
    if ( $k eq '6') { $cv[2]+=0.2; update(); }

    if ( $k eq '1') { $cv[0]-=0.2; update(); }
    if ( $k eq '2') { $cv[1]-=0.2; update(); }
    if ( $k eq '3') { $cv[2]-=0.2; update(); }

    printf "Coeffiction: %.2f %.2f %.2f\n", $cv[0],$cv[1],$cv[2];
}

sub quit
{
    glutDestroyWindow( $WinID );
    exit 0;
}

sub main
{
    our $MAIN;

    glutInit();
    glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH_TEST | GLUT_MULTISAMPLE );
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

sub update
{
    $img2 = $img->copy();
    $img2->filter(type=>"conv", coef=>[ @cv ]);
    load_pixels( $img2, $W, $H );
}

sub load_pixels
{
    my ($img, $W, $H) = @_;
    my @rgba_arr;
    my ($r, $g, $b, $y, $x);

    our @colors;
    our @verts;
    @colors = ();
    @verts = ();

    for $y ( 0 .. $H-1 )
    {
        @rgba_arr = $img->getscanline(y=>$y);
        for $x ( 0 .. $W-1 )
        {
            ($r, $g, $b) = ($rgba_arr[$x]->rgba)[0,1,2];
            push @colors, $r/255.0, $g/255.0, $b/255.0;
            push @verts, ( $x, $H-$y, 0.0 );
        }
    }
}