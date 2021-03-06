#!/usr/bin/env genome-perl
#Written by Malachi Griffith

#Purpose:
#This script parses xml files downloaded from clinicaltrials.gov and attempts to acquire drug-gene interactions from these records
#Each xml file corresponds to a single clinical trial
#The xml files conform to the following dtd
#http://clinicaltrials.gov/ct2/html/images/info/public.dtd

#Needed data / parameters
#A.) List of all annotation gene names (and synonymns foreach)
#B.) List of clinical trial record IDs
#C.) Path to directory containing xml records named as follows: $ClinTrialId.xml
#D.) Output directory for flatfile database files generated by mining interactions from the clinical trial records

#Building drug-gene interactions (possible methods)
#Assume that each record contains information on the drug (drug name, etc.) and condition (disease involved)
#The missing link is the relationship between each trial and the drug(s) it involves and genes
#In many cases there may be now defined relationship to a gene, in other cases, there may be a defined relationship but it is not recorded in a systematic way
#Method 1.  Key word based - search for gene names
#Method 2.  MESH term based - search for gene names
#Method 3.  Text mining of one or more of the freeform text fields in the xml record... (search: 'brief_title', 'brief_summary', 'eligibility', etc.)
#           Refer to the schema 'public.dtd' for more details

#Steps
#- Import gene names and synonyms from Entrez flatfiles (limit to human only)
#- Import list of clinical trial record IDs from a .txt file
#- Parse the xml and apply each method to look for interactions with each possible gene
#- Store useful info from each clinical trial in an object keyed on clinical trial ID
#- Store interactions associated with each gene ID or synonym
#- Make note of *how many* clinical trial records are associated with each gene.  Genes with large numbers of interactions may be spurious
#- Dump interactions found to 3 flatfiles (genes, drugs, interactions)

use strict;
use warnings;
use Term::ANSIColor qw(:constants);
use Getopt::Long;
use Data::Dumper;
use XML::Simple;
binmode(STDOUT, ":utf8");
use Cwd 'abs_path';
use above 'Genome';
use Genome::Model::ClinSeq::Util qw(:all);

my $lib_dir;
BEGIN{
  if (abs_path($0) =~ /(.*\/).*\/.*\.pl/){
    $lib_dir = $1."/druggenes";
  }
}
use lib $lib_dir;
use utility qw(:all);

my $annotation_dir = '';
my $record_ids_file = '';
my $kw_blacklist_file = '';
my $xml_dir = '';
my $outdir = '';
my $debug = '';
my $record_limit = '';
my $verbose = '';

GetOptions ('annotation_dir=s'=>\$annotation_dir, 'record_ids_file=s'=>\$record_ids_file, 'kw_blacklist_file=s'=>\$kw_blacklist_file, 'xml_dir=s'=>\$xml_dir, 'outdir=s'=>\$outdir , 'debug=s'=>\$debug, 'record_limit=i'=>\$record_limit, 'verbose=i'=>\$verbose);

my $usage=<<INFO;

  Example usage: 
  
  parseClinicalTrialsGovXml.pl  --annotation_dir=/gscmnt/sata132/techd/mgriffit/reference_annotations/  --record_ids_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/ClinicalTrialsGov/record_ids_test.txt  --kw_blacklist_file=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/ClinicalTrialsGov/keyword_blacklist.txt  --xml_dir=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/ClinicalTrialsGov/xml_records_test/  --outdir=/gscmnt/sata132/techd/mgriffit/DruggableGenes/KnownDruggable/ClinicalTrialsGov/interactions/

  Details:
  --annotation_dir            PATH.  Directory containing gene info for gene name mapping ('gene2accession' and 'gene_info')
  --record_ids_file           PATH.  File containing all Clinical Trials IDs to be considered
  --kw_blacklist_file         PATH.  File containing keywords that will not be allowed when attempting to match records to Gene Names
  --xml_dir                   PATH.  Directory containing all corresponding clinical trials XML files (one per record)
  --outdir                    PATH.  Directory to store interaction flatfiles generated by parsing the XML files
  --debug                     INT.   Testing purposes
  --record_limit              INT.   Only process this many records 
  --verbose                   INT.   More output
INFO

unless ($annotation_dir && $record_ids_file && $kw_blacklist_file && $xml_dir && $outdir){
  print GREEN, "\n\n$usage\n\n", RESET;
  exit();
}
unless($record_limit){
  $record_limit = 1;
}

$annotation_dir = &checkDir('-dir'=>$annotation_dir, '-clear'=>"no");
$xml_dir = &checkDir('-dir'=>$xml_dir, '-clear'=>"no");
$outdir = &checkDir('-dir'=>$outdir, '-clear'=>"no");

#Import list of blacklisted keywords
my %kw_blacklist;
open(BL, "$kw_blacklist_file") || die "\n\nCould not open keyword blacklist file\n\n";
while(<BL>){
  chomp($_);
  $kw_blacklist{$_} = 1;
}
close(BL);

#Get annotation gene names and synonyms
print BLUE, "\n\nLoading gene annotation data from: $annotation_dir", RESET;
my $annotation_data = &loadEntrezEnsemblData();

my $entrez_symbols = $annotation_data->{'symbols'};
my $entrez_synonyms = $annotation_data->{'synonyms'};

#Get a list of clinical trials record IDs
my %rids = %{&getRecordIds('-infile'=>$record_ids_file)};

#Instantiate an XML simple object
my $xs1 = XML::Simple->new();

#Parse each XML and gather info to identify drug-gene interactions
my $r = 0;
my $rc = 0;

print BLUE, "\n\nParsing xml files in: $xml_dir", RESET;
foreach my $rid (sort keys %rids){
  $r++;
  my $xml_path = $xml_dir."$rid".".xml";

  if (-e $xml_path && -s $xml_path){
    if ($verbose){
      print CYAN, "\n\t$r: parsing ($xml_path)", RESET;
    }
    $rc++;
  }elsif(-e $xml_path && -z $xml_path){
    if ($verbose){
      print YELLOW, "\n\t$r: empty file ($xml_path)", RESET;
    }
    next();
  }else{
    print RED, "\n\nCould not find XML file for record ($rid): $xml_path\n\n", RESET;
    exit();
  }

  #Debug
  if ($rc > $record_limit && $debug){
    last();
  }
  
   my $xml = $xs1->XMLin($xml_path, KeyAttr => ['nct_id', 'id'] );
   my $study_type = $xml->{'study_type'};
   my $nct_id = $xml->{'id_info'}->{'nct_id'};
   my $id_info = $xml->{'id_info'};
   my $intervention = $xml->{'intervention'};
   my @intervention_names = @{&parseXmlTree('-ref'=>$intervention, '-value_name'=>'intervention_name')};
   my $in_count = scalar(@intervention_names);
   my @intervention_types = @{&parseXmlTree('-ref'=>$intervention, '-value_name'=>'intervention_type')};
   my $it_count = scalar(@intervention_types);
   my @secondary_ids = @{&parseXmlTree('-ref'=>$id_info, '-value_name'=>'secondary_id')};
   my @org_study_ids = @{&parseXmlTree('-ref'=>$id_info, '-value_name'=>'org_study_id')};
   my @keywords;

   #If intervention name and type are not defined, skip the record
   unless ($in_count && $it_count){
     next();
   }

   if ($xml->{'keyword'}){
     my $ref_test = ref($xml->{'keyword'});
     if ($ref_test eq "ARRAY"){
       @keywords = @{$xml->{'keyword'}};
     }else{
       push(@keywords, $xml->{'keyword'});
     }
   }
   my @upper = map { uc($_) } @keywords;
   @keywords = @upper;

   #Filter keywords to remove very short keywords and match them against a blacklist
   my @keywords_filt;
   foreach my $keyword (@keywords){
     if (length($keyword) <= 2){
       next();
     }
     if ($kw_blacklist{$keyword}){
       next();
     }
     push(@keywords_filt, $keyword);
   }
   @keywords = @keywords_filt;
   
   my $keyword_count = scalar(@keywords);

   #Look for matches to Entrez gene names in the key words
   my %symbol_matches;
 
   foreach my $keyword (@keywords){
     #print YELLOW, "\nDEBUG: kw = $keyword", RESET;
     if ($entrez_symbols->{$keyword}){
       $symbol_matches{$keyword}{entrez_ids} = $entrez_symbols->{$keyword}->{entrez_ids};
     }
   }
   my @symbol_list = keys %symbol_matches;
   my $symbol_match_count = scalar(@symbol_list);

   #Look for matches to Entrez gene names in the key words
   my %synonym_matches;
   foreach my $keyword (@keywords){
     if ($keyword eq "na"){next();}
     if ($entrez_synonyms->{$keyword}){
       $synonym_matches{$keyword}{entrez_ids} = $entrez_synonyms->{$keyword}->{entrez_ids};
     }
   }
   my @synonym_list = keys %synonym_matches;
   my $synonym_match_count = scalar(@synonym_list);

   if ($debug){
     print Dumper $xml;
   }

   if ($symbol_match_count > 0 || $synonym_match_count){
     print CYAN, "\n\t$r: parsing ($xml_path)", RESET;
     print YELLOW, "\n\t\tST: $study_type\tNCTID: $nct_id\tSID: @secondary_ids\tOSID: @org_study_ids\t", RESET;
     print YELLOW, "\n\t\tKW: @keywords", RESET;
     print YELLOW, "\n\t\tIN: @intervention_names", RESET;
     print YELLOW, "\n\t\tIT: @intervention_types", RESET;
     print MAGENTA, "\n\t\tSYMBOLS: @symbol_list", RESET;
     print MAGENTA, "\n\t\tSYNONYMS: @synonym_list", RESET;
   }



}




print "\n\n";

exit();

###################################################################################################
#Get a list of clinical trials record IDs                                                         #
###################################################################################################
sub getRecordIds{
  my %args = @_;
  my $infile = $args{'-infile'};
  
  print BLUE, "\n\nImporting record IDs from: $infile", RESET;
  my %rids;
  open (RID, "$infile") || die "\n\nCould not open record ids file: $infile\n\n";
  while(<RID>){
    chomp($_);
    $rids{$_}++;
  }
  close(RID);
  my $rid_count = keys %rids;
  print BLUE, "\n\tFound $rid_count record IDs", RESET;

  return(\%rids);
}




