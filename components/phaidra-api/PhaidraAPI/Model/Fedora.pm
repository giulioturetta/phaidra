package PhaidraAPI::Model::Fedora;

use strict;
use warnings;
use v5.10;
use utf8;
use JSON;
use Mojo::File;
use Digest::SHA qw(sha256_hex);
use base qw/Mojo::Base/;

my %prefix2ns = (

  # hasModel, state, ownerId
  "info:fedora/fedora-system:def/model#" => "fedora3",

  # hasCollectionMember
  "info:fedora/fedora-system:def/relations-external#" => "fedora3rel",

  # hasMember
  "http://pcdm.org/models#" => "pcdm",

  # references, identifier
  "http://purl.org/dc/terms/" => "dcterms",

  # isBackSideOf, isAlternativeFormatOf, isAlternativeVersionOf, isThumbnailFor
  "http://phaidra.org/XML/V1.0/relations#" => "porgrels",

  # hasSuccessor
  "http://phaidra.univie.ac.at/XML/V1.0/relations#" => "prels",

  # isInAdminSet
  "http://phaidra.org/ontology/" => "pont",

  # hasTrack
  "http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#" => "ebucore"
);

sub getFirstJsonldValue {
  my ($self, $c, $jsonld, $p) = @_;

  for my $ob (@{$jsonld}) {
    if (exists($ob->{$p})) {
      for my $ob1 (@{$ob->{$p}}) {
        if (exists($ob1->{'@value'})) {
          return $ob1->{'@value'};
        }
      }
    }
  }
}

sub getJsonldValue {
  my ($self, $c, $jsonld, $p) = @_;

  my @a;
  for my $ob (@{$jsonld}) {
    if (exists($ob->{$p})) {
      for my $ob1 (@{$ob->{$p}}) {
        if (exists($ob1->{'@value'})) {
          push @a, $ob1->{'@value'};
        }
      }
      last;
    }
  }
  return \@a;
}

sub _getObjectProperties {
  my ($self, $c, $pid) = @_;

  my $res = {alerts => [], status => 200};

  my $url = $c->app->fedoraurl->path($pid);
  $c->app->log->debug("GET $url");
  my $getres = $c->ua->get($url => {'Accept' => 'application/ld+json'})->result;

  if ($getres->is_success) {
    $res->{props} = $getres->json;
  }
  else {
    unshift @{$res->{alerts}}, {type => 'error', msg => $getres->message};
    $res->{status} = $getres->{code};
    return $res;
  }
  return $res;
}

sub getObjectProperties {
  my ($self, $c, $pid) = @_;

  my $res = {alerts => [], status => 200};

  my $propres = $self->_getObjectProperties($c, $pid);
  if ($propres->{status} != 200) {
    return $propres;
  }

  my $props = $propres->{props};

  # cmodel
  my $cmodel = $self->getFirstJsonldValue($c, $props, 'info:fedora/fedora-system:def/model#hasModel');
  $cmodel =~ m/(info:fedora\/)(\w+):(\w+)/g;
  if ($2 eq 'cmodel' && defined($3) && ($3 ne '')) {
    $res->{cmodel} = $3;
  }

  $res->{state}    = $self->getFirstJsonldValue($c, $props, 'info:fedora/fedora-system:def/model#state');
  $res->{label}    = $self->getFirstJsonldValue($c, $props, 'info:fedora/fedora-system:def/model#label');
  $res->{created}  = $self->getFirstJsonldValue($c, $props, 'http://fedora.info/definitions/v4/repository#created');
  $res->{modified} = $self->getFirstJsonldValue($c, $props, 'http://fedora.info/definitions/v4/repository#lastModified');

  # $res->{owner}                  = $self->getJsonldValue($c, $props, 'http://fedora.info/definitions/v4/repository#createdBy');
  $res->{owner}                  = $self->getFirstJsonldValue($c, $props, 'info:fedora/fedora-system:def/model#ownerId');
  $res->{identifier}             = $self->getJsonldValue($c, $props, 'http://purl.org/dc/terms/identifier');
  $res->{references}             = $self->getJsonldValue($c, $props, 'http://purl.org/dc/terms/references');
  $res->{isbacksideof}           = $self->getJsonldValue($c, $props, 'http://phaidra.org/XML/V1.0/relations#isBackSideOf');
  $res->{isthumbnailfor}         = $self->getJsonldValue($c, $props, 'http://phaidra.org/XML/V1.0/relations#isThumbnailFor');
  $res->{hassuccessor}           = $self->getJsonldValue($c, $props, 'http://phaidra.univie.ac.at/XML/V1.0/relations#hasSuccessor');
  $res->{isalternativeformatof}  = $self->getJsonldValue($c, $props, 'http://phaidra.org/XML/V1.0/relations#isAlternativeFormatOf');
  $res->{isalternativeversionof} = $self->getJsonldValue($c, $props, 'http://phaidra.org/XML/V1.0/relations#isAlternativeVersionOf');
  $res->{isinadminset}           = $self->getJsonldValue($c, $props, 'http://phaidra.org/ontology/isInAdminSet');
  $res->{haspart}                = $self->getJsonldValue($c, $props, 'info:fedora/fedora-system:def/relations-external#hasCollectionMember');
  $res->{hasmember}              = $self->getJsonldValue($c, $props, 'http://pcdm.org/models#hasMember');
  $res->{hastrack}               = $self->getJsonldValue($c, $props, 'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasTrack');
  $res->{sameas}                 = $self->getJsonldValue($c, $props, 'http://www.w3.org/2002/07/owl#sameAs');

  $res->{contains} = [];
  for my $ob (@{$props}) {
    if (exists($ob->{'http://www.w3.org/ns/ldp#contains'})) {
      for my $ob1 (@{$ob->{'http://www.w3.org/ns/ldp#contains'}}) {
        if (exists($ob1->{'@id'})) {
          push @{$res->{contains}}, (split '\/', $ob1->{'@id'})[-1];
        }
      }
    }
  }
  # $c->app->log->debug("XXXXXXXXXXXXXXX getObjectProperties:\n".$c->app->dumper($res));
  return $res;
}

sub addRelationship {
  my ($self, $c, $pid, $predicate, $object, $skiphook) = @_;

  return $self->addRelationships($c, $pid, ({predicate => $predicate, object => $object}), $skiphook);
}

sub addRelationships {
  my ($self, $c, $pid, $relationships, $skiphook) = @_;

  return $self->insertTriples($c, $pid, $relationships);
}

sub removeRelationship {
  my ($self, $c, $pid, $predicate, $object, $skiphook) = @_;

  return $self->removeRelationships($c, $pid, ({predicate => $predicate, object => $object}), $skiphook);
}

sub removeRelationships {
  my ($self, $c, $pid, $relationships, $skiphook) = @_;

  return $self->deleteTriples($c, $pid, $relationships);
}

sub _getPrefProp {
  my ($self, $c, $predicate) = @_;

  for my $prefix (keys %prefix2ns) {
    if (rindex($predicate, $prefix, 0) == 0) {
      $predicate =~ s/$prefix//;
      return ($prefix, $predicate);
    }
  }
}

sub deleteTriples {
  my ($self, $c, $pid, $properties) = @_;

  return $self->_deleteOrInsertTriples($c, $pid, $properties, 'DELETE');
}

sub insertTriples {
  my ($self, $c, $pid, $properties) = @_;

  return $self->_deleteOrInsertTriples($c, $pid, $properties, 'INSERT');
}

sub _deleteOrInsertTriples {
  my ($self, $c, $pid, $properties, $action) = @_;

  my $prefixes = "";
  my $values   = "";
  for my $p (@{$properties}) {
    my ($pref, $prop) = $self->_getPrefProp($c, $p->{predicate});
    my $ns  = $prefix2ns{$pref};
    my $val = $p->{object};

    $prefixes .= "PREFIX " . $ns . ": <" . $pref . ">\n";
    $values   .= "<> $ns:$prop \"$val\".\n";
  }
  my $body = qq|
    $prefixes
    $action {
      $values
    }
    WHERE { }
  |;

  return $self->_sparqlPatch($c, $pid, $body);
}

sub editTriples {
  my ($self, $c, $pid, $properties) = @_;

  my $res = {alerts => [], status => 200};

  my $propres = $self->_getObjectProperties($c, $pid);
  if ($propres->{status} != 200) {
    return $propres;
  }

  my $currentValues = $propres->{props};

  my $prefixes  = "";
  my $oldValues = "";
  my $newValues = "";
  for my $p (@{$properties}) {

    if ($p->{predicate} eq 'info:fedora/fedora-system:def/model#state') {
      $p->{object} = 'Active'   if $p->{object} eq 'A';
      $p->{object} = 'Inactive' if $p->{object} eq 'I';
      $p->{object} = 'Deleted'  if $p->{object} eq 'D';
    }

    # if eg
    # $p->{predicate} = info:fedora/fedora-system:def/model#state
    # $p->{object} = "A"
    # and current value is "Inactive"
    # we want
    #
    # PREFIX fedora3: <info:fedora/fedora-system:def/model#>
    # DELETE {
    #   <> fedora3:state "Inactive"
    # }
    # INSERT {
    #   <> fedora3:state "Active"
    # }
    # WHERE { }
    my ($pref, $prop) = $self->_getPrefProp($c, $p->{predicate});
    my $ns     = $prefix2ns{$pref};
    my $curVal = $self->getJsonldValue($c, $currentValues, $p->{predicate});
    my $newVal = $p->{object};

    $prefixes  .= "PREFIX " . $ns . ": <" . $pref . ">\n";
    $oldValues .= "<> $ns:$prop \"$curVal\"\n";
    $newValues .= "<> $ns:$prop \"$newVal\"\n";
  }
  my $body = qq|
    $prefixes
    DELETE {
      $oldValues .
    }
    INSERT {
      $newValues .
    }
    WHERE { }
  |;

  my $patchRes = $self->_sparqlPatch($c, $pid, $body);
}

sub _sparqlPatch {
  my ($self, $c, $pid, $body) = @_;

  my $res = {alerts => [], status => 200};

  my $url = $c->app->fedoraurl->path($pid);
  $c->app->log->debug("PATCH $url\n$body");

  my $patchres = $c->ua->patch($url => {'Content-Type' => 'application/sparql-update'} => $body)->result;
  unless ($patchres->is_success) {
    $c->app->log->error("Cannot update triples for pid[$pid]: code:" . $patchres->{code} . " message:" . $patchres->{message});
    unshift @{$res->{alerts}}, {type => 'error', msg => $patchres->{message}};
    $res->{status} = $patchres->{code} ? $patchres->{code} : 500;
    return $res;
  }

  return $res;
}

sub getDatastreamsHash {
  my ($self, $c, $pid) = @_;

  my $res = {alerts => [], status => 200};

  my $propres = $self->getObjectProperties($c, $pid);
  if ($propres->{status} != 200) {
    return $propres;
  }

  my %dsh;
  if (exists($propres->{contains})) {
    for my $contains (@{$propres->{contains}}) {
      $dsh{$contains} = 1;
    }
  }

  $res->{dshash} = \%dsh;

  $c->app->log->debug("getDatastreamsHash\n" . $c->app->dumper(\%dsh));

  return $res;
}

sub getDatastream {
  my ($self, $c, $pid, $dsid) = @_;

  my $res = {alerts => [], status => 200};

  $c->app->log->debug("getDatastream pid[$pid] dsid[$dsid]");

  if ($dsid eq "OCTETS") {
    unshift @{$res->{alerts}}, {type => 'error', msg => "getDatastream is not meant for OCTETS"};
    $res->{status} = 400;
    return $res;
  }

  my $url = $c->app->fedoraurl->path("$pid/$dsid");
  $c->app->log->debug("GET $url");
  my $getres = $c->ua->get($url)->result;

  if ($getres->is_success) {
    $res->{$dsid} = $getres->body;

    # $c->app->log->debug("getDatastream\n" . $getres->body);
  }
  else {
    unshift @{$res->{alerts}}, {type => 'error', msg => $getres->message};
    $res->{status} = $getres->{code};
    return $res;
  }

  return $res;
}

sub getDatastreamAttributes {
  my ($self, $c, $pid, $dsid) = @_;

  my $res = {alerts => [], status => 200};

  $c->app->log->debug("getDatastreamSize pid[$pid] dsid[$dsid]");

  my $url = $c->app->fedoraurl->path("$pid/$dsid/fcr:metadata");
  $c->app->log->debug("GET $url");
  my $getres = $c->ua->get($url => {'Accept' => 'application/ld+json'})->result;

  if ($getres->is_success) {
    $res->{size} = $self->getFirstJsonldValue($c, $getres->json, 'http://www.loc.gov/premis/rdf/v1#hasSize');
    $res->{mimetype} = $self->getFirstJsonldValue($c, $getres->json, 'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasMimeType');
    $res->{filename} = $self->getFirstJsonldValue($c, $getres->json, 'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#filename');
    $res->{modified} = $self->getFirstJsonldValue($c, $getres->json, 'http://fedora.info/definitions/v4/repository#lastModified');
    $res->{created} = $self->getFirstJsonldValue($c, $getres->json, 'http://fedora.info/definitions/v4/repository#created');
  }
  else {
    unshift @{$res->{alerts}}, {type => 'error', msg => $getres->message};
    $res->{status} = $getres->{code};
    return $res;
  }

  return $res;
}

sub getDatastreamPath {
  my ($self, $c, $pid, $dsid) = @_;

  my $res = {alerts => [], status => 200};

  my $resourceID = "info:fedora/$pid";
  my $hash = sha256_hex($resourceID);

  my $first   = substr($hash, 0, 3);
  my $second  = substr($hash, 3, 3);
  my $third  = substr($hash, 6, 3);

  my $ocflroot = $c->app->config->{fedora}->{ocflroot};
  my $objRootPath ="$ocflroot/$first/$second/$third/$hash";

  my $inventoryFile = "$objRootPath/inventory.json";
  my $bytes = Mojo::File->new($inventoryFile)->slurp;
  my $inventory = decode_json($bytes);

  # sanity check
  unless ($inventory->{id} eq $resourceID) {
    unshift @{$res->{alerts}}, {type => 'error', msg => "Reading wrong inventory file resourceID[$resourceID] file[$inventoryFile]"};
    $res->{status} = 500;
    return $res;
  }

  my $head = $inventory->{head};
  my $state = $inventory->{versions}->{$head}->{state};
  my $dsLatestKey;
  for my $key (keys %{$state}) {
    if (@{$state->{$key}}[0] eq $dsid) {
      $dsLatestKey = $key;
      last;
    }
  }
  my $pathArr = $inventory->{manifest}->{$dsLatestKey};

  my $path = @{$pathArr}[0];
  $res->{path} = "$objRootPath/$path";

  $c->app->log->debug("pid[$pid] head[$head] dsid[$dsid] dspath[$path]");

  return $res;
}

sub addOrModifyDatastream {
  my ($self, $c, $pid, $dsid, $location, $dscontent, $upload, $mimetype, $checksumtype, $checksum) = @_;

  my $res = {alerts => [], status => 200};

  if ($location) {
    my $url = $c->app->fedoraurl->path("$pid/LINK");
    $c->app->log->debug("PUT $url Link $location");
    my $putres = $c->ua->put($url => {'Link' => "$location; rel=\"http://fedora.info/definitions/fcrepo#ExternalContent\"; handling=\"redirect\"; type=\"text/plain\""})->result;
    unless ($putres->is_success) {
      $c->app->log->error("pid[$pid] PUT Link $location error code:" . $putres->{code} . " message:" . $putres->{message});
      unshift @{$res->{alerts}}, {type => 'error', msg => $putres->{message}};
      $res->{status} = $putres->{code} ? $putres->{code} : 500;
      return $res;
    }
  }

  if ($dscontent) {
    my $headers;
    $headers->{'Content-Type'} = $mimetype;
    if ($checksumtype) {
      $headers->{digest} = "$checksumtype=$checksum";
    }
    my $url = $c->app->fedoraurl->path("$pid/$dsid");
    $c->app->log->debug("PUT $url");
    my $putres = $c->ua->put($url => $headers => $dscontent)->result;
    unless ($putres->is_success) {
      $c->app->log->error("pid[$pid] dsid[$dsid] PUT error code:" . $putres->{code} . " message:" . $putres->{message});
      unshift @{$res->{alerts}}, {type => 'error', msg => $putres->{message}};
      $res->{status} = $putres->{code} ? $putres->{code} : 500;
      return $res;
    }
  }

  if ($upload) {
    my $headers;
    $headers->{'Content-Type'}        = $mimetype;
    $headers->{'Content-Disposition'} = 'attachment; filename="' . $upload->filename . '"';
    if ($checksumtype) {
      $headers->{digest} = "$checksumtype=$checksum";
    }
    my $url = $c->app->fedoraurl->path("$pid/$dsid");
    $c->app->log->debug("PUT $url filename[" . $upload->filename . "] mimetype[$mimetype]");
    my $tx = $c->ua->build_tx(PUT => $url => $headers);
    $tx->req->content->asset($upload->asset);
    my $putres = $c->ua->start($tx)->result;

    # my $putres = $c->ua->put($url => $headers => $upload->asset)->result;
    unless ($putres->is_success) {
      $c->app->log->error("Cannot create fedora object pid[$pid]: code:" . $putres->{code} . " message:" . $putres->{message});
      unshift @{$res->{alerts}}, {type => 'error', msg => $putres->{message}};
      $res->{status} = $putres->{code} ? $putres->{code} : 500;
      return $res;
    }
  }

  return $res;
}

sub createEmpty {
  my ($self, $c, $username) = @_;

  my $res = {alerts => [], status => 200};

  my $mint = $self->mintPid($c);
  if ($mint->{status} != 200) {
    return $mint;
  }
  my $pid = $mint->{pid};

  my $body = qq|
    \@prefix fedora3: <info:fedora/fedora-system:def/model#>.
    <>
    fedora3:state \"Inactive";
    fedora3:ownerId \"$username\".
  |;

  my $url = $c->app->fedoraurl->path($pid);
  $c->app->log->debug("PUT $url\n$body");
  my $putres = $c->ua->put($url => {'Content-Type' => 'text/turtle', 'Link' => '<http://fedora.info/definitions/v4/repository#ArchivalGroup>;rel="type"'} => $body)->result;
  unless ($putres->is_success) {
    $c->app->log->error("Cannot create fedora object pid[$pid]: code:" . $putres->{code} . " message:" . $putres->{message});
    unshift @{$res->{alerts}}, {type => 'error', msg => $putres->{message}};
    $res->{status} = $putres->{code} ? $putres->{code} : 500;
    return $res;
  }

  $res->{pid} = $pid;

  return $res;
}

sub mintPid {
  my ($self, $c) = @_;

  my $res = {alerts => [], status => 200};
  my $dbh = $c->app->db_metadata->dbh;
  my $ns  = $c->app->config->{fedora}->{pidnamespace};
  $dbh->do("UPDATE pidGen SET highestID = LAST_INSERT_ID(highestID) + 1 WHERE namespace = '$ns';");
  my $highestID = $dbh->last_insert_id(undef, undef, 'pidGen', 'highestID');
  if (my $msg = $dbh->errstr) {
    $c->app->log->error($msg);
    $res->{status} = 500;
    unshift @{$res->{alerts}}, {type => 'error', msg => $msg};
    return $res;
  }
  $highestID++;
  $res->{pid} = "$ns:$highestID";
  return $res;
}

1;
__END__
