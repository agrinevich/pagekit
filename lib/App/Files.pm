package App::Files;

use strict;
use warnings;

use English qw( -no_match_vars );
use Carp qw(croak carp);
use Path::Tiny;
use File::Copy::Recursive qw(dircopy pathempty);
use Number::Bytes::Human qw(format_bytes);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

our $VERSION = '0.2';

sub get_files {
    my (%args) = @_;

    my $dir_str    = $args{dir};
    my $dirs_only  = $args{dirs_only} || 0;
    my $files_only = $args{files_only} || 0;

    my $path = Path::Tiny->new($dir_str);

    return [] if !( $path->exists && $path->is_dir );

    my @result;
    my @o_children = $path->children;

    foreach my $o_child (@o_children) {
        next if $dirs_only  && !$o_child->is_dir;
        next if $files_only && !$o_child->is_file;

        my $size = -s $o_child;

        push @result, {
            name => $o_child->basename,
            size => format_bytes($size),
        };
    }

    return \@result;
}

sub file_handle {
    my (%args) = @_;

    my $file    = $args{file};
    my $mode    = $args{mode};
    my $binmode = $args{binmode};

    my $o_file = Path::Tiny->new($file);
    my $fh     = $o_file->filehandle( $mode, $binmode );

    return $fh;
}

sub read_file {
    my (%args) = @_;

    my $file = $args{file};

    return Path::Tiny->new($file)->slurp_utf8;
}

sub write_file {
    my (%args) = @_;

    my $file = $args{file};
    my $body = $args{body};

    # return Path::Tiny->new($file)->spew_utf8($body);
    return Path::Tiny->new($file)->spew($body);
}

sub move_file {
    my (%args) = @_;

    my $src = $args{src};
    my $dst = $args{dst};

    return Path::Tiny->new($src)->move($dst);
}

sub copy_file {
    my (%args) = @_;

    my $src = $args{src};
    my $dst = $args{dst};

    return Path::Tiny->new($src)->copy($dst);
}

sub make_path {
    my (%args) = @_;

    my $path = $args{path};

    my $dir = Path::Tiny->new($path);

    return $dir->mkpath;
}

sub move_dir {
    my (%args) = @_;

    my $src_dir = $args{src_dir};
    my $dst_dir = $args{dst_dir};

    return if !-d $src_dir;

    # if ( !-d $dst_dir ) {
    #     make_path(
    #         path => $dst_dir,
    #     );
    # }

    # my $a_files = get_files(
    #     dir => $src_dir,
    # );

    # foreach my $h ( @{$a_files} ) {
    #     my $src_file = $src_dir . q{/} . $h->{name};
    #     my $dst_file = $dst_dir . q{/} . $h->{name};
    #     move_file(
    #         src => $src_file,
    #         dst => $dst_file,
    #     );
    # }

    # rmdir $src_dir;

    copy_dir_recursive(
        src_dir => $src_dir,
        dst_dir => $dst_dir,
    );

    empty_dir_recursive(
        dir => $src_dir,
    );

    rmdir $src_dir;

    return 1;
}

sub copy_dir_recursive {
    my (%args) = @_;

    my $src_dir = $args{src_dir};
    my $dst_dir = $args{dst_dir};

    # if dst_dir exists - delete it first
    my $o_dir = Path::Tiny->new($dst_dir);
    if ( $o_dir->is_dir() ) {
        empty_dir_recursive(
            dir => $dst_dir,
        );
        rmdir $dst_dir;
    }

    my ( $total_qty, $dirs_qty, $depth ) = File::Copy::Recursive::dircopy( $src_dir, $dst_dir )
        or croak $OS_ERROR;

    return ( $total_qty, $dirs_qty, $depth );
}

sub empty_dir_recursive {
    my (%args) = @_;

    my $dir = $args{dir};

    File::Copy::Recursive::pathempty($dir)
        or croak $OS_ERROR;

    return;
}

sub create_zip {
    my (%args) = @_;

    my $src_dir = $args{src_dir};
    my $dst_dir = $args{dst_dir};
    my $name    = $args{name};

    my $file = $dst_dir . q{/} . $name . '.zip';

    my $zip = Archive::Zip->new();
    $zip->addTree( $src_dir, $name );
    if ( $zip->writeToFileNamed($file) != AZ_OK ) {
        croak 'write error';
    }

    my $size = -s $file;

    return {
        file => $file,
        size => format_bytes($size),
    };
}

sub extract_zip {
    my (%args) = @_;

    my $file    = $args{file};
    my $dst_dir = $args{dst_dir};

    my $zip = Archive::Zip->new();
    my $rs  = $zip->read($file);

    if ( $rs != AZ_OK ) {
        return 'Failed to read: ' . $file;
    }

    my $real_dir = path($dst_dir)->realpath;

    my $es = $zip->extractTree( undef, $real_dir );

    return $es == AZ_OK ? q{} : 'Failed to extract';
}

# TODO: move to Admin::Templ
# sub build_tree {
#     my ($h_args) = @_;

#     my $root_dir    = $h_args->{root_dir};
#     my $tpl_path    = $h_args->{tpl_path};
#     my $parent_path = $h_args->{parent_path};
#     my $level       = $h_args->{level} // 0;
#     my $h_selected  = $h_args->{h_selected} // {};

#     my %sel    = %{$h_selected};
#     my $dash   = sprintf q{&nbsp;-} x $level;
#     my $cwd    = $root_dir . $parent_path;
#     my $result = q{};

#     my $a_files = get_files( dir => $cwd );
#     my @names   = map { $_->{name} } @{$a_files};
#     foreach my $name ( sort @names ) {
#         my $cur_file = $cwd . q{/} . $name;
#         my $o_file   = Path::Tiny->new($cur_file);

#         if ( $o_file->is_dir ) {
#             $result .= Util::Renderer::parse_html(
#                 root_dir => $root_dir,
#                 tpl_path => $tpl_path . '/templ',
#                 tpl_name => 'list-dir.html',
#                 h_vars   => {
#                     cwd  => $cwd,
#                     name => $name,
#                     # size => $h->{size},
#                     dash => $dash,
#                 }
#             );

#             $result .= build_tree(
#                 {
#                     root_dir    => $root_dir,
#                     tpl_path    => $tpl_path,
#                     parent_path => $parent_path . q{/} . $name,
#                     level       => $level + 1,
#                     h_selected  => $h_selected,
#                 }
#             );
#         }
#         else {
#             my $attr = $sel{$cur_file} // q{};

#             $result .= Util::Renderer::parse_html(
#                 root_dir => $root_dir,
#                 tpl_path => $tpl_path . '/templ',
#                 tpl_name => 'list-file.html',
#                 h_vars   => {
#                     cwd  => $cwd,
#                     name => $name,
#                     # size => $h->{size},
#                     attr => $attr,
#                     dash => $dash,
#                 }
#             );
#         }
#     }

#     return $result;
# }

1;
