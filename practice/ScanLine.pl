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
}

INIT:
{
    ' Load picture ';

    my $file = "../sample.jpg"; 
    our $img = Imager->new();
    our ($H, $W);
    our @cv = (1.0, 2.0, 1.0);
    
    $img->read(file=>$file) or die "Cannot load image: ", $img->errstr;
    ($H, $W) = ($img->getheight(), $img->getwidth());
    printf "width: %d, height: %d\n", $W, $H;

    our $mat = [[]];
    our @verts;
    our @colors;
    our $vtx_n = $W * $H;
    load_pixels($img, $W, $H);
    #only get list in once
    our $verts  = OpenGL::Array->new_list( GL_FLOAT, @verts );
    our $colors = OpenGL::Array->new_list( GL_FLOAT, @colors );

    our $volumn = [
        [0.1, 0.3, 0.4, 0.3, 0.1],
        [0.3, 0.6, 0.8, 0.6, 0.3],
        [0.4, 0.8, 1.0, 0.8, 0.4],
        [0.3, 0.6, 0.8, 0.6, 0.3],
        [0.1, 0.3, 0.4, 0.3, 0.1],
    ];

    our $hash;
    our @sort_key;
}

&main();

sub display
{
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

    glPointSize(4.0);
    glColor3f(1.0, 0.0,0.0);
    glBegin(G_POINTS);
    glVertex3f($xi, $yi, 1.0);
    glEnd();
    # printf "x:%d : %.2f %.2f %.2f\n", $xi, @{$mat->[$yi][$xi]};

    #get block
    my $block = [[]];
    my $sum = 0.0;
    my $far = 3;
    if ($xi > 3)
    {
        for my $my (-$far .. $far)
        {
            for my $mx ( -$far .. $far )
            {
                $block->[$my+$far][$mx+$far] = $mat->[ $yi+$my ][ $xi+$mx ][0];
                #printf "%-3d ", $block->[$my+2][$mx+2];
                $sum += $block->[$my+$far][$mx+$far];
            }
            #print "\n";
        }
        #print "\n";
    }

    printf "%03d %.3f\n", $xi, $sum;
    $xi+=1.0 if $xi < $W-1;

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
            $mat->[$y][$x] = [$r, $g, $b];

            $hash->{"$r $g $b"} += 1;
        }
    }

    @sort_key = sort { $hash->{$b} <=> $hash->{$a} } keys %$hash;
    print $sort_key[0] ,"\n";
    print $sort_key[$#sort_key] ,"\n";
}