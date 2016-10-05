package Yapess::SudokuXMatrix;
use base 'Yapess::SudokuMatrix';
use Carp;
use Set::Scalar;

sub build_rbcx {
  my $self = shift;
  $mat = $self->{mat};
  my $diag = [ Set::Scalar->new(), Set::Scalar->new() ];
  foreach my $i (0..8) {
    my $el = $mat->[$i][$i];
    $el->{diag} = [ $diag->[0] ];
    $diag->[0]->insert($el);
    $el = $mat->[$i][8-$i];
    if ($i == 4) {
      push( @{ $el->{diag} }, $diag->[1] );
    } else {
      $el->{diag} = [ $diag->[1] ];
    }
    $diag->[1]->insert($el);
  }
  $self->{diag} = $diag;
}

sub new {
  my $class = shift;
  $self = $class->SUPER::new();
  $self->build_rbcx();
  bless $self, $class;
  return $self;
}

sub fix {
  my $self = shift;
  $self->SUPER::fix(@_);
  my ( $el, $mat );
  if ( 'HASH' eq ref($_[0]) ) {
    $el = shift;
  } else {
    my $i = shift;
    my $j = shift;
    $mat = $self->{mat};
    $el = $mat->[$i][$j];
  }
  my $val = shift;
  
  my $diags = $el->{diag};
  if ($diags) {
    foreach my $diag (@$diags) {
      $diag->delete($el);
      foreach my $elm ($diag->elements) {
        $self->clear($elm, $val) if ($elm != $el and !$elm->{final});
      }
    }
  }
}

sub simplify {
  my $self = shift;

  my $flag = $self->SUPER::simplify();
  my $diag = $self->{diag};
  foreach my $s (@$diag) { $flag = 1 if $self->simplify_set($s) }
  return $flag;
}

1;
