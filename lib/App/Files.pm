package App::Files;

use strict;
use warnings;

use English qw( -no_match_vars );
use Carp qw(croak carp);
use Path::Tiny;
use Try::Tiny;
use Imager;
use Number::Bytes::Human qw(format_bytes);
use File::Copy::Recursive qw(dircopy pathempty);
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

    return $src_dir . ' doesnt exist' if !-d $src_dir;

    my $success = File::Copy::Recursive::dirmove( $src_dir, $dst_dir );

    return $success ? undef : 'error: ' . $!;
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

sub scale_image {
    my (%args) = @_;

    my $file_src = $args{file_src};
    my $file_dst = $args{file_dst};
    my $width    = $args{width};
    my $height   = $args{height};

    my $is_ok = try {
        my $o_image_src = Imager->new() or croak 'Failed to read: ' . Imager->errstr();

        $o_image_src->read(
            file => $file_src,
        ) or croak 'Failed to read: ' . $o_image_src->errstr;

        my $o_image_dst = $o_image_src->scale(
            xpixels => $width,
            ypixels => $height,
            type    => 'min',
        );

        $o_image_dst->write(
            file => $file_dst,
        ) or croak 'Failed to save: ', $o_image_dst->errstr;

        return 1;
    }
    catch {
        carp("Failed to scale_image: $_");
        return;
    };

    return $is_ok;
}

1;
