#!/bin/bash

#==============================================================================
#title           :mamage_org.sh
#description     :This script is a compilation of all the commonly used CCI commands
#usage           :Under Help
#=======================================

function help {
    echo "**This is script written to help QE manage scratch org either for testing or regression purpose **"
    echo "Below Options can be provided:"
    echo ' \t '"
           -o        org to base the new scratch org from
           -n        new orgname to be created
           -f        flowname to be applied [ regression/dev/qa]
           -d        active days
           -a        action to perform [create/delete/list/info ]
           -p        additional actions to create an additional usre or to enable rd2 within the org [createuser/rd2] "

    echo "Create a new org or rebuild an org :     ./manage_scratchorg.sh [-o org] [-n orgname] [-f feature] [-d days] [-a create]"
    echo "Create a new org with rd2 enabled :     ./manage_scratchorg.sh [-o org] [-n orgname] [-f feature] [-d days] [-a create] [-p rd2]"
    echo "Delete an org:                           ./manage_scratchorg.sh  [-n orgname] [-a delete]"
    echo "List org based on selection criteria:    ./manage_scratchorg.sh [-w word] [-a list]"
    echo "Print org info :                         ./manage_scratchorg.sh  [-n orgname] [-a info]"
    echo "Create Test user :                       ./manage_scratchorg.sh  [-n orgname] [-p createuser]"
}
function createusage {

    echo "usage: ./manage_scratchorg.sh [-o org] [-n orgname] [-f feature] [-d days] [-a action]"
    echo "Example: ./manage_org.sh -o dev -n testrj -f regression -d 5  -a create"
    echo "Note: Try to provide a unique org name and prefix it with your initials (Eg: rj_regression_org )"
}
function deleteusage {
    clear
    echo  "\nusage: ./manage_scratchorg.sh  [-n orgname] [-a action]"
    echo "Example: ./manage_org.sh -n testrj -a delete"
}
function infousage {

    echo "usage: ./manage_scratchorg.sh  [-n orgname] [-a action]"
    echo "Example: ./manage_org.sh -n testrj -a info"
}

# Prints the list of commandline arguments passed
function printvariables {
  clear
  echo "Creating a scratch org with the below information..."
  echo "org: $org"
  echo "orgname: $orgname"
  echo "flowname: $flowname"
  echo "daysactive: $daysactive"
  echo "action: $action"
  echo "additional params: $params"
}
# Deletes the org specified
function deleteorg {
  clear
  count=`cci org list | grep -i -w $orgname | wc -l`
  if [[ "$count" -ne  1 ]]
   then
     echo " No orgs found with the specified name. Pleae try to give valid complete orgname "
  fi
  echo 'Deleting scratch org...'
  cci org scratch_delete $orgname
  cci org remove $orgname
}

# Executes cci commands to create an org and run the specified flow
function runcreateorgsteps {
  echo "Creating new org with the below parameters..."
  printvariables
  cci org scratch $org $orgname --days $daysactive
  cci org default $orgname
  cci flow run $flowname --org $orgname
  cci org browser $orgname
}

# Checks if the orgname already exists and prompts the user for recreation
function createorg {

  count=`cci org list | grep -i -w $orgname | wc -l`
  if [[ "$count" -ge  1 ]]
   then
    echo "Orgname already exists. Do you want to delete and recreate [Y/N]?"
    read userinput
    userinput=$(echo ${userinput} | tr '[:upper:]' '[:lower:]')
    if [[ ( $userinput == "y" ) ]]
    then
     cci org scratch_delete $orgname
     cci org remove $orgname
     runcreateorgsteps
    fi
    if [[ ( $userinput == "n" ) ]]
    then
     createusage
    fi

  else
   runcreateorgsteps
  fi

}

function listorgs {
    clear
    echo "orgs matching the specified selection ..."
    if [ -z "$lookuptext" ]
    then
      cci org list
    fi
    cci org list > orgs.txt
    egrep $lookuptext orgs.txt

}
function printorginfo {
  clear
  count=`cci org list | grep -i -w $orgname | wc -l`
  if [[ "$count" -ne  1 ]]
   then
     echo " No orgs found with the specified name. Please create one "
     exit 1
  fi
  cci org info $orgname
}
# Creates an additianal testuser non-default admin
function createuser {
    clear
    echo "Running a flow to generate a testuser in the org ..."
    cci flow run create_testing_user --org $orgname
}

# Enables rd2 based on the org type
function enable_rd2 {
    if [[ "$flowname" -eq  "qa" ]]
     then
       echo "Running enable rd2 flow for unmanaged orgs ..."
       cci flow run enable_rd2 --org $orgname
    fi
    if [[ "$flowname" -eq  "regression" ]]
     then
       echo "Running enable rd2 flow for managed orgs ..."
       cci flow run enable_rd2_managed --org $orgname
    fi
    if [[ -z "$flowname" ]]
     then
       cci flow run enable_rd2_managed --org $orgname
    fi

}

# get the specified command line opts
while getopts o:d:a:f:n:w:p:h opt ; do
   case $opt in
      o) org=$OPTARG ;;
      n) orgname=$OPTARG ;;
      f) flowname=$OPTARG ;;
      d) daysactive=$OPTARG;;
      a) action=$OPTARG;;
      w) lookuptext=$OPTARG;;
      p) params=$OPTARG;;
      h) help;;
   esac
done

# If user did not specify any org, flow or days default the values

if [ -z "$org" ]
then
      org="dev"
fi
if [ -z "$daysactive" ]
then
      daysactive=7
fi
if [ -z "$flowname" ]
then
      flowname="regression"
fi

# convert the action provided from the command line into lowwercase
action=$(echo ${action} | tr '[:upper:]' '[:lower:]')
flowname=$flowname'_org'

# Validations to check right number of arguments are passed for each action
if [[ $action == "delete"  &&  "$#" -ne  4 ]]
  then
    deleteusage
fi
if [[ $action == "create"  &&   -z "$orgname" ]]
 then
    createusage
fi
if [[ $action == "info"  &&   -z "$orgname" ]]
 then
    infousage
fi

# Execute the cci actions based on the commandline action arguments

if [[ ( $action == "create" ) ]]
 then
     createorg
fi
if [[ ( $action == "delete" ) ]]
 then
     deleteorg
fi
if [[ ( $action == "list" ) ]]
 then
     listorgs
fi
if [[ ( $action == "info" ) ]]
 then
     printorginfo
fi
if [[ $params == "createuser" ]]
 then
    createuser
fi
if [[ $params == "rd2" ]]
 then
    enable_rd2
fi


