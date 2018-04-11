#!/usr/bin/perl
use HTML::Template;
use Switch;
use strict;
################### Configure the coming variables
# to be suitable for your environment
my $DATADIR="data";
my $INVFILE="inv.dat";
my $INVDETFILE="invdet.dat";
################################################ end of app main vars

my $template;
my %ST;
my $k;
my $op;



sub sendErrorMsg {
my $ErrMsg;
    ($ErrMsg)=@_;
                    $template = HTML::Template->new(filename => 'errmsg.templ');
                    $template->param(ERRMSG => "$ErrMsg");
                    print $template->output;
}

### extractArgs function, extract the QUERY_STRING from %ENV and create a new fetchrow_hashref
# key:value are VAR:value
sub extractArgs() {
  my @ARGS;
  my %QRYSTR;
  my $k;
  my $v;
  my $l;
  @ARGS=split /&/,%ENV{'QUERY_STRING'};
  foreach $l ( @ARGS) {
    ($k,$v)=split /=/,$l;
    $QRYSTR{$k}=$v;
  }
  return %QRYSTR;
}

sub queryInvDetailByInvID {
    my ($template,$inv_id)=@_;
    my $invdetfile;
    my @alldet;
    my $line;
    my @detinfo=();
    
    $invdetfile="$DATADIR/$INVDETFILE";
    open(INVDET,"<",$invdetfile);
        @alldet=<INVDET>;
    close(INVDET);
    foreach $line ( @alldet) {
        if ( $line =~ m/^$inv_id:/ ) {
            my %invdetline;
            ($inv_id,$invdetline{ITEMID},$invdetline{NAME},$invdetline{ITEMQU},$invdetline{ITEMUP})=split /:/,$line;
            push(@detinfo,\%invdetline);
        }
    }
    $template->param(INV_DETINFO => \@detinfo);
    return $template;
}

#Query the data about about invoice with invoice id
sub queryInvoice {
    my %parms=@_;
    my $inv_id;
    my @allinv;
    my $invline;
    my @invcomp;
    my $found;
    my $fname;
    ## Again check if the user pass the id parameter needed.
    if ( ! exists($parms{'id'} ) ) {
                    sendErrorMsg("Missing Invoice ID");
                    return;
    }
    $fname="$DATADIR/$INVFILE";
    open(INVF,"<",$fname) or die "Error opening the file : $fname";
        @allinv=<INVF>;
    close(INVF);
    $inv_id=$parms{'id'};
    $found=0;
    foreach $invline (@allinv) {
    
        if ( $invline=~ m/^$inv_id:/ ) {
            @invcomp=split /:/,$invline;
            $found=1;
        }
    }
    if ( $found ) {
        $template = HTML::Template->new(filename => 'invquery.templ');    
        $template->param(f_invid => "$invcomp[0]" ); 
        $template->param(f_custname => "$invcomp[1]" ); 
        $template->param(f_invtotal => "$invcomp[2]" ); 
        $template=queryInvDetailByInvID($template,$inv_id);
        print $template->output;
    }
    else {
                    sendErrorMsg("Invoice id $inv_id can not found");
    }
    return;
}

#Query the database for the invoice with largest total and displays its info and details.
sub queryLargeInvoiceTotal() {
my $CO;
my $fname;
my $invline;
my $inv_id;
my $custname;
my $total;
my $minv_id;
my $mcustname;
my $mtotal;
my @allinv;
my $inv_id_href;
$CO=1;
    $fname="$DATADIR/$INVFILE";
    open(INVF,"<",$fname) or die "Error opening the file : $fname";
        @allinv=<INVF>;
    close(INVF);
foreach $invline ( @allinv ) {
    ($inv_id,$custname,$total)=split /:/,$invline;
    if ( $CO == 1 ) {
        ($minv_id,$mcustname,$mtotal)=($inv_id,$custname,$total);
        $CO++;
    }
    else {
        if ( $total > $mtotal) {
            ($minv_id,$mcustname,$mtotal)=($inv_id,$custname,$total);
        }
    }    
}
        $template = HTML::Template->new(filename => 'querybytotal.templ');    
        $inv_id_href="<a href=invop.pl?op=qi&id=$minv_id>$minv_id</a>";
        $template->param(f_invid => "$inv_id_href" ); 
        $template->param(f_custname => "$mcustname" ); 
        $template->param(f_invtotal => "$mtotal" ); 
        print $template->output;
}

#Query the database about a certain item, and displays the total quantity sold for this item, and displays all invoices contains that item
sub queryItemQuantity {
my %parms=@_;
my $fname;
my $ifname;
my $INVDF;
my $ITEM_ID;
my @allitem;
my $found;
my @itemcomp;
my $itemline;
my $qunt=0;
my $tprice=0;  
my $itemname;
my @invitem;
my @allinv;
my @invlinearr;
my @invinfo;
my $tmpinvid;
## Again check if the user pass the item id parameter needed.
    if ( ! exists($parms{'id'} ) ) {
                    sendErrorMsg("Missing Item ID..");
                    return;
    }
    $fname="$DATADIR/$INVDETFILE";
    $ifname="$DATADIR/$INVFILE";
    open(INVDF,"<",$fname) or die "Error opening the file : $fname";
        @allitem=<INVDF>;
    close(INVDF);
    $ITEM_ID=$parms{'id'};
    @allitem=grep /^[0-9]*:$ITEM_ID:/, @allitem;
    $found=0;
    open(INVITEM,"<",$ifname);
        @allinv=<INVITEM>;
    close(INVITEM);
        foreach $itemline (@allitem)  {
            @itemcomp=split /:/,$itemline;
                $qunt=$qunt + $itemcomp[3];
                $itemname=$itemcomp[2];
                $tprice=$tprice+$itemcomp[3] * $itemcomp[4];
            $found=1;
            @invlinearr=grep /^$itemcomp[0]:/, @allinv;   
            my %invlineh;
            ($tmpinvid,$invlineh{CUSTNAME},$invlineh{INVTOTAL})=split /:/,$invlinearr[0];
            $invlineh{INVID}="<a href=invop.pl?op=qi&id=$tmpinvid>$tmpinvid</a>";
            push(@invinfo,\%invlineh);
    }
        if ( $found ) {
        $template = HTML::Template->new(filename => 'queryitemqsold.templ');    
        $template->param(f_itemid => "$ITEM_ID" ); 
        $template->param(f_itemname => "$itemname" ); 
        $template->param(f_itemqsold => "$qunt" ); 
        $template->param(f_itemtsold => "$tprice" ); 
        $template->param(INV_ITEMINFP => \@invinfo);
        print $template->output;
    }
    else {
                    sendErrorMsg("Item id $ITEM_ID can not found");
    }
}

#Send HTML Tag
print "Content-Type: text/html\n\n";
%ST=extractArgs();

if ( ! exists ($ST{'op'})) {
    sendErrorMsg("Missed operation");
    exit 1;
}

$op=$ST{'op'};
#$template = HTML::Template->new(filename => 'invquery.templ');
## To get the op, which contains the operation we want to perform 
## qi: to query an invoice with its details using the invoice id
## ql: To query the invoice with bigger total, and get its details
## qq: To query an item with sum of its item sold
switch ($op) {
    case "qi"   { queryInvoice(%ST); }              #To query 
    case "ql"   { queryLargeInvoiceTotal(); }
    case "qq"   { queryItemQuantity(%ST); }
    else        { 
                    sendErrorMsg("Invalid Operation");
                    exit 1;
                }    
}
