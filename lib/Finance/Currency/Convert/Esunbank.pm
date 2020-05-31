package Finance::Currency::Convert::Esunbank;
use strict;
use warnings;

our $VERSION = v0.1.0;

use Exporter 'import';
our @EXPORT_OK = qw(get_currencies convert_currency);

use POSIX qw(strftime);
use Mojo::Collection;
use Mojo::UserAgent;
use Mojo::JSON qw(encode_json);

sub get_currencies {
    my ($error, $result);

    my $dom;
    eval {
        $dom = _fetch_currency_exchange_web_page();
    } or do {
        $error = @$;
    };
    return ($error, undef) if defined $error;
 
    my @rows = $dom->find("table.tableStyle2 tr")->map(
        sub {
            my ($el) = @_;
            my @cells = $el->find("td")->each;
            return unless @cells;

            my @names = $cells[0]->all_text =~ m/ (\p{Han}+) \( (\p{Latin}{3}) \) /x;
            return {
                currency => $names[1],
                zh_currency_name => $names[0],
                en_currency_name => $names[1],
                buy_at => $cells[2]->all_text,
                sell_at => $cells[2]->all_text,
            };
        })->each;

    return (undef, \@rows);
}

sub convert_currency {
    my ($amount, $from_currency, $to_currency) = @_;
    return ("The convertion target must be 'TWD'. Cannot proceed with '$to_currency'", undef) unless $to_currency eq 'TWD';

    my ($error, $result) = get_currencies();
    return ($error, undef) if defined $error;

    my $rate;
    for (@$result) {
        if ($_->{currency} eq $from_currency) {
            $rate = $_;
            last;
        }
    }
    return ("Unknown currency: $from_currency", undef) unless $rate;

    return (undef, $amount * $rate->{buy_at});
}

sub _fetch_currency_exchange_web_page {
    my @t = localtime();
    my $ua = Mojo::UserAgent->new;
    $ua->transactor->name('Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:76.0) Gecko/20100101 Firefox/76.0');
    my $result = $ua->get('https://www.esunbank.com.tw/bank/iframe/widget/rate/foreign-exchange-rate')->result;
    die $result->message if $result->is_error;
    return $result->dom;
}

1;
