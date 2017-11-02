use utf8;
use Imager;
use Encode;
use feature 'state';
use Math::Trig;
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
    our $d_threshold = 5.0;
}

INIT:
{
    ' Load picture ';

    my $file = "sample3.jpg"; 
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
    scan_edge();

    sub scan_edge
    {
        @edges = ();
        my $prev, $curr, $k, $y;
        my ($cy, $cx) = ( int($H/2), int($W/2) );
        my $ang = 0.0;

        my @points;
        my ($x, $y, $len);
        my $e_mat, $t_mat;
        my $best, $min;

        for ( $ang = 0.0 ; $ang <= 6.28; $ang += 0.1 )
        {
            $len = 600.0;
            @points = ();
            $prev = undef;

            while ( $len > 1.0 )
            {
                $len -= 1.0;
                $x = $cx + $len * cos( $ang );
                $y = $cy + $len * sin( $ang );
                next if ( $y > $H-5 or $x > $W-5 or $x < 0.0 or $y < 0.0);

                $curr = $mat->[$y][$x][0];
                if (not defined $prev) { $prev = $curr; next; }

                $k = abs($curr-$prev);
                if ( $k > $k_threshold )
                {
                    push @points, [$x, $H-$y, 1.0];
                }
                $prev = $curr;
            }

            my $t_mat;
            if ( $#points >= 0 )
            {
                if ( $#edges < 1 )
                {
                    ' get first point ';
                    push @edges, $points[0];
                    
                    @$e_mat = ();

                    for my $si ( -100 .. 100 ) {
                    for my $sj ( -100 .. 100 ) {
                        push @$e_mat, $mat->[ $points[0]->[1]+$si ][ $points[0]->[0]+$sj ][0]
                    }
                    }
                    #@$e_mat = sort @$e_mat;
                }
                else
                {
                    ' similar test ';
                    $min = 1000000.0;
                    $best = 0;
                    for my $pi ( 0 .. $#points )
                    {
                        @$t_mat = ();
                        for my $si ( -100 .. 100 ) {
                        for my $sj ( -100 .. 100 ) {
                            push @$t_mat, $mat->[ $points[$pi]->[1]+$si ][ $points[$pi]->[0]+$sj ][0]
                        }
                        }
                        #@$t_mat = sort @$t_mat;

                        my $sum = 0;
                        for my $mi ( 0 .. $#$e_mat )
                        {
                            $sum += ($e_mat->[$mi] - $t_mat->[$mi]) ** 2;
                        }
                        $sum = sqrt($sum);
                        #printf "%.3f\n", $sum;

                        if ( $sum < $min )
                        {
                            $best = $pi;
                            $min = $sum;
                        }
                    }

                    @$e_mat = ();
                    for my $si ( -100 .. 100 ) {
                    for my $sj ( -100 .. 100 ) {
                        push @$e_mat, $mat->[ $points[$best]->[1]+$si ][ $points[$best]->[0]+$sj ][0]
                    }
                    }
                    #@$e_mat = sort @$e_mat;

                    push @edges, $points[$best];
                }
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
    glBegin(GL_POINTS);
    glColor3f(1.0, 1.0, 0.0);
    for my $e ( 0 .. $#edges )
    {
        glColor3f( 1.0-$e/$#edges, $e/$#edges, 0.6 );
        glVertex3f( @{$edges[$e]} );
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
    state $fa = 100.0;
    my ($w, $h) = (shift, shift);
    my $p_max = max( $H, $W );
    my $w_min = min( $h, $w );

    $p_max = $p_max - $p_max % 10;  '取整';

    glViewport(0, 0, $w_min, $w_min);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho( 0.0, $p_max, 0.0, $p_max, 0.0, $fa*2.0); 
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(0.0,0.0,$fa, 0.0,0.0,0.0, 0.0,1.0, $fa);
}

sub hitkey
{
    our $WinID;
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
    $WinID = glutCreateWindow("Detect Contour");
    
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
