
BIN_DIR = ../../bin

KENT_DIR = ${HOME}/kent/src
INCL = -I${KENT_DIR}/inc  -I${KENT_DIR}/hg/inc
ARCH = $(shell uname -m)
MACHTYPE = ${ARCH}
LIBS = ${KENT_DIR}/lib/${ARCH}/jkweb.a ${KENT_DIR}/lib/${ARCH}/jkhgap.a


# check from kent/src/inc/common.mk
ifeq (${SAMTABIXDIR},)
    SAMTABIXDIR = /hive/data/outside/samtabix/${MACHTYPE}
    ifneq ($(wildcard ${SAMTABIXDIR}),)
        ifeq (${USE_SAMTABIX},)
          USE_SAMTABIX=1
        endif
    endif
endif
# libsamtabix (samtools + tabix + Angie's KNETFILE_HOOKS extension to it): disabled by default
ifeq (${USE_SAMTABIX},1)
    USE_BAM=1
    USE_TABIX=1
    ifeq (${SAMTABIXINC},)
        SAMTABIXINC = ${SAMTABIXDIR}
    endif
    ifeq (${SAMTABIXLIB},)
        SAMTABIXLIB = ${SAMTABIXDIR}/libsamtabix.a
    endif
    LIBS+=${SAMTABIXLIB} -lz
else
  # Deprecated but supported for mirrors, for now: independent samtools and tabix libs

  # libbam (samtools, and Angie's KNETFILE_HOOKS extension to it): disabled by default
  ifeq (${USE_BAM},1)
      ifeq (${SAMLIB},)
          SAMLIB = ${SAMDIR}/libbam.a
      endif
      LIBS+=${SAMLIB}
  endif

# libtabix and Angie's KNETFILE_HOOKS extension to it: disabled by default
  ifeq (${USE_TABIX},1)
      ifeq (${TABIXINC},)
          TABIXINC = ${TABIXDIR}
      endif
      ifeq (${TABIXLIB},)
          TABIXLIB = ${TABIXDIR}/libtabix.a
      endif
      LIBS+=${TABIXLIB} -lz
  endif
endif
LIBS += -lssl -lm


CIMPLFLAGS += -std=c99 -D__USE_FIXED_PROTOTYPES__ -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_GNU_SOURCE
CWARNFLAGS += -Wall -W -pedantic -Werror -Wno-sign-compare -Wno-unused-parameter -fno-strict-aliasing

CFLAGS += -g ${INCL} ${CIMPLFLAGS} ${CWARNFLAGS}


PROG = ${BIN_DIR}/postTransMapChain

all: ${PROG}

test:
	(cd test && ${MAKE} test)

${BIN_DIR}/%: %.c
	@mkdir -p $(dir $@)
	${CC} ${CFLAGS} $< -o $@ ${LIBS}


clean:
	rm -f ${PROG}

savebak:
	savebak postTransMapChain *.c Makefile tests/Makefile tests/input
