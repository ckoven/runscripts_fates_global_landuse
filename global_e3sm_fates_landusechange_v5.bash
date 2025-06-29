#!/usr/bin/env bash

SRCDIR=$HOME/E3SM/components/elm/src/
cd ${SRCDIR}
GITHASH1=`git log -n 1 --format=%h`
cd external_models/fates
GITHASH2=`git log -n 1 --format=%h`

#STAGE=AD_SPINUP
STAGE=POSTAD_SPINUP
#STAGE=TRANSIENT_LU_CONSTANT_CO2_CLIMATE
#STAGE=TRANSIENT_LU_TRANSIENT_CO2_CLIMATE

if [ "$STAGE" = "AD_SPINUP" ]; then
    SETUP_CASE=f45_030_adspinup_potveg
elif [ "$STAGE" = "POSTAD_SPINUP" ]; then
    SETUP_CASE=f45_0032_postadspinup_potveg
elif [ "$STAGE" = "TRANSIENT_LU_CONSTANT_CO2_CLIMATE" ]; then
    SETUP_CASE=f45_0017_1750translanduse_frompotveg
fi
    
CASE_NAME=${SETUP_CASE}_${GITHASH1}_${GITHASH2}
basedir=$HOME/E3SM/cime/scripts

cd $basedir
export RES=f45_f45
project=m2467

./create_newcase -case ${CASE_NAME} -res ${RES} -compset I1850GSWCNPRDCTCBCTOP -mach pm-cpu -project $project


cd $CASE_NAME

ncgen -o fates_params_default_${GITHASH2}.nc ${SRCDIR}/external_models/fates/parameter_files/fates_params_default.cdl

# add more age bins to history output
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --O --var=fates_history_ageclass_bin_edges --val=0,1,2,5,10,20,50,100,200 --changeshape

# log daily
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --O --var=fates_landuse_logging_event_code --val=3

# make the seed rain amount nonzero for grasses (cool c3 and c4 grasses)
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --pft 13 --var fates_recruit_seed_supplement --val 1e-4 --O
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --pft 14 --var fates_recruit_seed_supplement --val 1e-4 --O

#turn on grazing
/global/homes/c/cdkoven/E3SM/components/elm/src/external_models/fates/tools/modify_fates_paramfile.py --fin=fates_params_default_${GITHASH2}.nc --fout=fates_params_default_${GITHASH2}.nc --O --var fates_landuse_grazing_rate --val 0,0,.01,.02,0

# debugging phase
# ./xmlchange DEBUG=TRUE
# ./xmlchange STOP_N=6
# ./xmlchange STOP_OPTION=nmonths
# ./xmlchange JOB_QUEUE=debug

# fates_harvest_mode = 'no_harvest'
# fates_harvest_mode = 'luhdata_area'

if [ "$STAGE" = "AD_SPINUP"  ]; then

    ./xmlchange RUN_STARTDATE=0001-01-01
    #./xmlchange RUN_STARTDATE=0100-01-01  ## because taking a prior run's restart file in AD mode, so need to circumvent the 20 year thing
    ./xmlchange RESUBMIT=3
    ./xmlchange ELM_ACCELERATED_SPINUP=on
    ./xmlchange -id ELM_BLDNML_OPTS -val "-bgc fates -no-megan -no-drydep -bgc_spinup on"
    ./xmlchange NTASKS=-5
    ./xmlchange STOP_N=30
    ./xmlchange REST_N=5
    ./xmlchange STOP_OPTION=nyears
    ./xmlchange JOB_QUEUE=debug
    ./xmlchange JOB_WALLCLOCK_TIME=00:30:00
    ./xmlchange CCSM_CO2_PPMV=287.
    
    #./xmlchange DATM_MODE=CLMCRUNCEP
    ./xmlchange DATM_CLMNCEP_YR_START=1901
    ./xmlchange DATM_CLMNCEP_YR_END=1920
    ./xmlchange DATM_PRESAERO=clim_1850

    cat > user_nl_elm <<EOF
fsurdat = '/global/cfs/cdirs/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_4x5_simyr2000_c130927.nc'
flandusepftdat = '/global/homes/c/cdkoven/scratch/inputdata/fates_landuse_pft_map_4x5_20240206.nc'
use_fates_luh = .true.
use_fates_nocomp = .true.
use_fates_fixed_biogeog = .true.
fates_paramfile = '${basedir}/${CASE_NAME}/fates_params_default_${GITHASH2}.nc'
use_fates_sp = .false.
fates_spitfire_mode = 1
fates_harvest_mode = 'no_harvest'
use_fates_potentialveg = .true.
fluh_timeseries = ''
use_century_decomp = .true.
spinup_state = 1
suplphos = 'ALL'
suplnitro = 'ALL'
fates_parteh_mode = 2
nu_com = 'RD'
hist_fincl1 = 'FATES_SECONDARY_AREA_ANTHRO_AP','FATES_SECONDARY_AREA_AP','FATES_PRIMARY_AREA_AP','FATES_NPP_LU','FATES_GPP_LU','PROD10C','PROD100C','PRODUCT_CLOSS','FATES_SEEDS_IN_PF','FATES_SEEDS_IN_LOCAL_PF'
paramfile = '/global/homes/c/cdkoven/scratch/inputdata/clm_params_c211124_mod_ddefold.nc'
fates_radiation_model = 'twostream'
fates_leafresp_model = 'ryan1991'
EOF
#suplphos = 'ALL'
#suplnitro = 'ALL'
    
elif [ "$STAGE" = "POSTAD_SPINUP" ]; then

    ./xmlchange RUN_STARTDATE=0001-01-01
    ./xmlchange RESUBMIT=0
    ./xmlchange ELM_ACCELERATED_SPINUP=off
    ./xmlchange NTASKS=-5
    ./xmlchange STOP_N=1
    ./xmlchange REST_N=1
    ./xmlchange STOP_OPTION=nyears
    ./xmlchange JOB_QUEUE=debug
    ./xmlchange JOB_WALLCLOCK_TIME=00:30:00
    ./xmlchange CCSM_CO2_PPMV=287.
    ./xmlchange -id ELM_BLDNML_OPTS -val "-bgc fates -no-megan -no-drydep"

    # ./xmlchange RUN_TYPE=hybrid
    # ./xmlchange RUN_REFCASE=fates_e3sm_perlmttr_fullmodel_4x5_test_landuse_nocomp_startfrompotentialveg_0006_bgcspinup_v1_377b2d31d7_ed007e30
    # ./xmlchange RUN_REFDIR=/global/homes/c/cdkoven/scratch/e3sm_scratch/pm-cpu/fates_e3sm_perlmttr_fullmodel_4x5_test_landuse_nocomp_startfrompotentialveg_0006_bgcspinup_v1_377b2d31d7_ed007e30/run/
    # #./xmlchange RUN_REFDIR=~/scratch/restfiles/
    # ./xmlchange RUN_REFDATE=0261-01-01
    # ./xmlchange GET_REFCASE=FALSE

    #./xmlchange DATM_MODE=CLMCRUNCEP
    ./xmlchange DATM_CLMNCEP_YR_START=1901
    ./xmlchange DATM_CLMNCEP_YR_END=1920
    ./xmlchange DATM_PRESAERO=clim_1850


    cat > user_nl_elm <<EOF
fsurdat = '/global/cfs/cdirs/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_4x5_simyr2000_c130927.nc'
flandusepftdat = '/global/homes/c/cdkoven/scratch/inputdata/fates_landuse_pft_map_4x5_20240206.nc'
finidat='/global/homes/c/cdkoven/scratch/restfiles/f45_030_adspinup_potveg_5fd137b0c9_13268f7a.elm.r.0346-01-01-00000.nc'
use_fates_luh = .true.
use_fates_nocomp = .true.
use_fates_fixed_biogeog = .true.
fates_paramfile = '${basedir}/${CASE_NAME}/fates_params_default_${GITHASH2}.nc'
use_fates_sp = .false.
fates_spitfire_mode = 1
fates_harvest_mode = 'no_harvest'
use_fates_potentialveg = .true.
fluh_timeseries = ''
use_century_decomp = .true.
spinup_state = 0
suplphos = 'ALL'
suplnitro = 'ALL'
fates_parteh_mode = 2
nu_com = 'RD'
paramfile = '/global/homes/c/cdkoven/scratch/inputdata/clm_params_c211124_mod_ddefold.nc'
fates_radiation_model = 'twostream'
fates_leafresp_model = 'atkin2017'
EOF

elif [ "$STAGE" = "TRANSIENT_LU_CONSTANT_CO2_CLIMATE" ]; then

    ./xmlchange RUN_STARTDATE=1751-01-01
    ./xmlchange RESUBMIT=1
    ./xmlchange ELM_ACCELERATED_SPINUP=off
    ./xmlchange NTASKS=-5
    ./xmlchange STOP_N=30
    ./xmlchange REST_N=5
    ./xmlchange STOP_OPTION=nyears
    ./xmlchange JOB_QUEUE=debug
    ./xmlchange JOB_WALLCLOCK_TIME=00:30:00
    ./xmlchange CCSM_CO2_PPMV=287.
    ./xmlchange -id ELM_BLDNML_OPTS -val "-bgc fates -no-megan -no-drydep"

    #./xmlchange DATM_MODE=CLMCRUNCEP
    ./xmlchange DATM_CLMNCEP_YR_START=1901
    ./xmlchange DATM_CLMNCEP_YR_END=1920
    ./xmlchange DATM_PRESAERO=clim_1850

    # ./xmlchange DATM_CLMNCEP_YR_ALIGN=11
    ### for 1801 start case, since forcing cycle is 20 years and offset is 50,
    ### move forcing alignment by 10 years so that it lines up with runs that start in 1851 and 1751.
    
    cat > user_nl_elm <<EOF
fsurdat = '/global/cfs/cdirs/e3sm/inputdata/lnd/clm2/surfdata_map/surfdata_4x5_simyr2000_c130927.nc'
flandusepftdat = '/global/homes/c/cdkoven/scratch/inputdata/fates_landuse_pft_map_4x5_20240206.nc'
use_fates_luh = .true.
use_fates_nocomp = .true.
use_fates_fixed_biogeog = .true.
fates_paramfile = '${basedir}/${CASE_NAME}/fates_params_default_${GITHASH2}.nc'
use_fates_sp = .false.
fates_spitfire_mode = 1
fates_harvest_mode = 'luhdata_area'
use_fates_potentialveg = .false.
fluh_timeseries = '/global/homes/c/cdkoven/scratch/inputdata/LUH2_states_transitions_management.timeseries_4x5_hist_simyr1650-2015_c240216.nc'
use_century_decomp = .true.
spinup_state = 0
suplphos = 'ALL'
suplnitro = 'ALL'
fates_parteh_mode = 2
nu_com = 'RD'
finidat = '/global/homes/c/cdkoven/scratch/restfiles/f45_0015_postadspinup_potveg_gswp3_d3b202343c_ae17acb2.elm.r.0031-01-01-00000.nc'
hist_fincl1 = 'FATES_SECONDARY_ANTHRODISTAGE_AP','FATES_SECONDARY_AREA_AP','FATES_PRIMARY_AREA_AP','FATES_NPP_LU','FATES_GPP_LU','PROD10C','PROD100C','PRODUCT_CLOSS'
paramfile = '/global/homes/c/cdkoven/scratch/inputdata/clm_params_c211124_mod_ddefold.nc'
fates_radiation_model = 'twostream'
fates_leafresp_model = 'atkin2017'
EOF

fi


./case.setup
./case.build
./case.submit
