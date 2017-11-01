use feature 'state';
use IO::Handle;
use Imager;
use List::Util;
use File::Slurp;
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

    my $file = "../sample2.jpg"; 
    our $img = Imager->new();
    our ($H, $W);
    
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
    our @edges;

    our $xi, $yi;
    $yi = int($H/2);
    scan_first_edge();

    sub scan_first_edge
    {
        my $prev, $curr, $k, $y;
        my ($cy, $cx) = ( int($H/2), int($W/2) );
        my $ang = 0.0;

        my @points;
        my ($x, $y, $len);

        for ( $ang = 0.0 ; $ang <= 6.28; $ang += 0.1 )
        {
            $len = 0.0;
            @points = ();
            $prev = $mat->[$cy][$cx][0];
            $x = $cx;
            $y = $cy;

            while ( $x < $W-1 and $y < $H-1 and $x > 0 and $y > 0 )
            {
                $len += 1.0;
                $x = $cx + $len * cos( $ang );
                $y = $cy + $len * sin( $ang );
                $curr = $mat->[$y][$x][0];
                $k = abs($curr-$prev);
                #print "$x, $y, $k\n";
                if ( $k > 30.0 )
                {
                    push @points, [$x, $H-$y, 1.0];
                }
                $prev = $mat->[$y][$x][0];
            }

            if ( $#points >= 0 )
            {
                # if ( $#edges < 0 )
                # {
                    ' get last point ';
                    push @edges, $points[$#points];
                # }
                # else
                # {
                #     ' distance test ';
                #     my $min = 1000.0;
                #     my $good = $#points;
                #     my $dt;
                #     for my $i ( 0 .. $#points )
                #     {
                #         $dt = sqrt(($points[$i]->[0]-$edges[$#edges]->[0])**2 + ($points[$i]->[1]-$edges[$#edges]->[1])**2);
                #         if ( $dt < $min)
                #         {
                #             $good = $i;
                #             $min = $dt;
                #         }
                #     }
                #     push @edges, $points[$good];
                # }
            }
            else 
            {
                print "did not find edge\n";
            }
        }

        export_svg( \@edges );
    }
}

&main();

sub display
{
    our ($xi, $yi);
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

    glPointSize(5.0);
    glColor3f(1.0, 0.0,0.0);

    glBegin(GL_POINTS);
    for my $e ( @edges )
    {
        glVertex3f( @$e );
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
    my $tv;

    for $y ( 0 .. $H-1 )
    {
        @rgba_arr = $img->getscanline(y=>$y);
        for $x ( 0 .. $W-1 )
        {
            ($r, $g, $b) = ($rgba_arr[$x]->rgba)[0,1,2];
            #三色平均，转灰度
            $tv = ($r+$g+$b)/3.0;
            push @colors, $tv/255.0, $tv/255.0, $tv/255.0;
            push @verts, ( $x, $H-$y, 0.0 );

            #实际rgb三个向量相同
            $mat->[$y][$x] = [$tv, $tv, $tv];
            $hash->{"$r $g $b"} += 1;
        }
    }

    @sort_key = sort { $hash->{$b} <=> $hash->{$a} } keys %$hash;
    print $sort_key[0] ,"\n";
    print $sort_key[$#sort_key] ,"\n";
}

sub export_svg
{
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

# sub export_svg
# {
#     my $pts = shift;
#     my $head = '<svg width="100%" height="100%" version="1.1" xmlns="http://www.w3.org/2000/svg">';
#     my $body = '<path d="';

#     $body .= sprintf "M%d %d ", $pts->[0][0], $H - $pts->[0][1];
#     for my $i ( 1 .. $#$pts )
#     {
#         $body .= sprintf "L%d %d ", $pts->[$i][0], $H - $pts->[$i][1];
#     }
#     $body .= 'Z"/>';

#     my $end = '</svg>';

#     write_file("contour.svg", join("\n", $head, $body, $end) );
# }