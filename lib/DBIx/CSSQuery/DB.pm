use strict;
use warnings;

package DBIx::CSSQuery::DB;

use self;

sub new {
    return bless {}, self;
}

sub attr {
    my ($attr, $value) = args;
    self->{$attr} = $value if defined $value;
    return self->{$attr};
}

1;
