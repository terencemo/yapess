package Yapess::SudokuMatrix;
use Carp;
use Set::Scalar;

our $VERSION = 0.01;

$| = 1;
our $debug = 0;
sub debug {
    print @_ if $debug;
}

sub new {
    my $class = shift;
    my $mat = [];
    my $block = [];
    for my $i (1..9) {
        my $row = [];
        for my $j (1..9) {
            push(@$row, {
                row => $i,
                col => $j,
                final => 0,
                set => Set::Scalar->new(1..9)
            } );
        }
        push(@$mat, $row);
    }
    my $build_block = sub {
        my ( $mat, $i, $j ) = @_;

        my $s = Set::Scalar->new();
        for my $k (0..2) {
            for my $l (0..2) {
                my $el = $mat->[3*$i+$k][3*$j+$l];
                $s->insert($el);
                $el->{block} = $s;
            }
        }
        return $s;
    };
    for my $i (0..2) {
        for my $j (0..2) {
            my $bk = &$build_block($mat, $i, $j);
            push(@$block, $bk);
        }
    }
    my $rowset = [];
    my $colset = [];
    foreach my $i (0..8) {
        my $rset = Set::Scalar->new();
        my $cset = Set::Scalar->new();
        foreach my $j (0..8) {
            $rset->insert($mat->[$i][$j]);
            $mat->[$i][$j]->{rowset} = $rset;
            $cset->insert($mat->[$j][$i]);
            $mat->[$j][$i]->{colset} = $cset;
        }
        push(@$rowset, $rset);
        push(@$colset, $cset);
    }
    my $self = {
        mat => $mat,
        block => $block,
        rowset => $rowset,
        colset => $colset,
        tofix => 81
    };
    bless $self, $class;
    return $self;
}

sub save {
    my $path = shift;
}

sub block {
    my ( $self, $i, $j ) = @_;

    return $self->{block}->[$i/3][$j/3];
}

sub clear {
    my ( $self, $el, $val ) = @_;
    
    debug("clear $val called for " . $el->{set} . "\n");
    return if $el->{final} or !$el->{set}->has($val);
    my $es = $el->{set};
    $es->delete($val);
#    $self->fix($el, $es->elements) if (1 == $es->size);
    return 1;
}

sub fix {
    my ( $self, $i, $j, $val ) = @_;

    my $mat = $self->{mat};
    my $el;
    if ( 'HASH' eq ref($i) ) {
        $el = $i;
        $val = $j;
    } else {
        $el = $mat->[$i][$j];
    }

    my $set = $el->{set};
    'Set::Scalar' eq ref($set)
        or croak("Unclear $set for $val at $i");
    $set->clear;
    $set->insert($val);
    $el->{final} = 1;
#    print "Remaining spaces: " . --$self->{tofix} . "\r";

    $el->{rowset}->delete($el);
    foreach my $elm ($el->{rowset}->elements) {
        $self->clear($elm, $val) if ($elm != $el and !$elm->{final});
    }
    $el->{colset}->delete($el);
    foreach my $elm ($el->{colset}->elements) {
        $self->clear($elm, $val) if ($elm != $el and !$elm->{final});
    }
    $el->{block}->delete($el);
    foreach my $elm ($el->{block}->elements) {
        $self->clear($elm, $val) if ($elm != $el and !$elm->{final});
    }
}

sub load {
    my ( $self, $path ) = @_;

    open(my $fh, $path) or croak("Unable to find file $path");
    my $i = 0;
    my $mat = $self->{mat};
    while (my $data = <$fh>) {
        chomp $data;
        my @chars = split(//, $data);
        my ( $j, $k ) = (0, 0);
        my $space = 0;
        while (my $ch = $chars[$k++]) {
            goto NEXTLINE if (1 == $k and $ch =~ m/[-%]/);
            if (0 == $space and '\\' eq $ch) {
                $space = 1;
            } elsif ('.' eq $ch) {
                ++$j; 
                $space = 0;
            } elsif ($ch =~ m/^\d$/) {
                if ($space) {
                    $j += $ch;
                    $space = 0;
                } else {
                    $self->fix($i, $j++, $ch);
                }
            } elsif ($ch =~ m/[ |]/) {
                1;
            } else  {
                croak("Illegal input $ch found in $path pos ".($i+1).":$k");
            }
        }
        ++$i;
        NEXTLINE: 1;
    }
    close($fh);
}

sub print {
    my $self = shift;

    my $lw = 9 * 3 + 2;
    my $sline = "+" . ( "-" x $lw ) . "+\n";
    my $eline = "|" . ( ' ' x $lw ) . "|\n";
    print $sline;
    print $eline;
    for my $i (0..8) {
        print "| ";
        for my $j (0..8) {
            my $this = $self->{mat}->[$i][$j];
            printf " %s ", $this->{final} ? $this->{set}->elements() : '.';
        }
        print " |\n";
        print $eline;
    }
    print $sline;
}

sub union {
    my $el = shift;
    debug "el: $el\n";
    my $s = $el->{set};
    debug("s=$s\n");
    foreach my $t (@_) { $s = $s->union($t->{set}) }
    return $s;
}

sub simplify_set {
    my $self = shift;
    my $sup = shift or return;
    my $flag = 0;
    foreach my $sub ($sup->power_set->elements) {
        next if ($sub->is_empty() or $sub == $sup);
        debug "sub: $sub\n";
        my $uset = union($sub->elements);
        if ($sub->size() == $uset->size()) {
            debug "sup: $sup,\nsub: $sub\n";
            my $comp = $sup - $sub;
            foreach my $el ($comp->elements) {
                next if ($el->{final} or 1 == $el->{set}->size());
                foreach my $val ($uset->elements) {
                    $flag = 1 if $self->clear($el, $val);
                }
            }
        }
    }
    return $flag;
}

sub simplify {
    my $self = shift;

    my $blk = $self->{block};
    my $rs = $self->{rowset};
    my $cs = $self->{colset};

    my $flag = 0;
    foreach my $s (@$rs) { $flag = 1 if $self->simplify_set($s) }
    foreach my $s (@$cs) { $flag = 1 if $self->simplify_set($s) }
    foreach my $s (@$blk) { $flag = 1 if $self->simplify_set($s) }
    return $flag;
}

sub solve {
    my $self = shift;

    my $mat = $self->{mat};
    my $flag;
    my $times = 0;
    do {
        $flag = 0;
        foreach my $i (0..8) {
            foreach my $j (0..8) {
                my $el = $mat->[$i][$j];
                if (!$el->{final} and 1 == $el->{set}->size) {
                    $self->fix($i, $j, $el->{set}->elements);
                    $flag = 1;
                }
            }
        }
        $flag ||= $self->simplify();
    } while ($flag);
}

1;

