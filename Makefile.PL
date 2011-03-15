use ExtUtils::MakeMaker;

WriteMakefile(
    NAME    => 'Yapess',
    VERSION_FROM => 'lib/Yapess/SudokuMatrix.pm',
    EXE_FILES   => [ 'script/yapess' ],
    PREREQ_PM   => {
        'Carp'          => 1.11,
        'Set::Scalar'   => 1.25
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (AUTHOR         => 'Terence Monteiro <terencemo@cpan.org>') : ()),
       LICENSE        => 'perl'
);
