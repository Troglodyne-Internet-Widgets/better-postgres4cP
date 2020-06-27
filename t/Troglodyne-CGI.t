use Test2::V0;
use File::Temp;
use FindBin;
use Capture::Tiny qw{capture_stdout};

use lib "$FindBin::Bin/lib"; # Test libraries
use lib "$FindBin::Bin/../lib"; # Code under test

use Troglodyne::CGI  ();
use Cpanel::Template ();

plan 1;

subtest "render_cached_or_process_template" => sub {
    my $tmp_obj = File::Temp->newdir();
    local $Troglodyne::CGI::ULC = $tmp_obj->dirname();
    my $input_hr = { 'template_file' => 'bogusbogus', 'print' => 1 };
    my $printed = capture_stdout {
        Troglodyne::CGI::render_cached_or_process_template( 'whostmongler', $input_hr );
    };
    my $test_str = "# [whostmongler] This is a test of Troglodyne::CGI. Please Ignore";
    is( $printed, $test_str, "Got the expected output when troglodyne_do_static_render invoked" );
    $input_hr->{'troglodyne_do_static_render'} = 1;
};
