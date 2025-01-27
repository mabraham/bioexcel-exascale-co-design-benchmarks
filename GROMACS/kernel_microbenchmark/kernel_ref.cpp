/*
 * This file is part of the GROMACS molecular simulation package.
 *
 * Copyright (c) 2012,2013,2014,2015,2016,2017,2018,2019, by the GROMACS development team, led by
 * Mark Abraham, David van der Spoel, Berk Hess, and Erik Lindahl,
 * and including many others, as listed in the AUTHORS file in the
 * top-level source directory and at http://www.gromacs.org.
 *
 * GROMACS is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * as published by the Free Software Foundation; either version 2.1
 * of the License, or (at your option) any later version.
 *
 * GROMACS is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with GROMACS; if not, see
 * http://www.gnu.org/licenses, or write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA.
 *
 * If you want to redistribute modifications to GROMACS, please
 * consider that scientific software is very special. Version
 * control is crucial - bugs must be traceable. We will be happy to
 * consider code for inclusion in the official distribution, but
 * derived work must not be called official GROMACS. Details are found
 * in the README & COPYING files - if they are missing, get the
 * official version at http://www.gromacs.org.
 *
 * To help us fund GROMACS development, we humbly ask that you cite
 * the research papers on the package. Check out http://www.gromacs.org.
 */
#include "kernel_ref.h"

#include <cassert>
#include <cmath>

#include <algorithm>

#include "gromacs/math/functions.h"
#include "gromacs/nbnxm/interaction_const.h"
#include "gromacs/pbcutil/ishift.h"

#include "kernel_datastructure_header.h"

/* Analytical reaction-field kernels */
/*
#define CALC_COUL_RF
#define LJ_CUT
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_CUT
#define LJ_FORCE_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_FORCE_SWITCH
#define LJ_POT_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_POT_SWITCH
#define LJ_EWALD
#define LJ_CUT
#define LJ_EWALD_COMB_GEOM
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_GEOM
#define LJ_EWALD_COMB_LB
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_LB
#undef LJ_CUT
#undef LJ_EWALD
#undef CALC_COUL_RF
*/

/* Tabulated exclusion interaction electrostatics kernels */
#define CALC_COUL_TAB
/*
#define LJ_CUT
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_CUT
#define LJ_FORCE_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_FORCE_SWITCH
#define LJ_POT_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_POT_SWITCH
#define LJ_EWALD
#define LJ_CUT
#define LJ_EWALD_COMB_GEOM
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_GEOM
#define LJ_EWALD_COMB_LB
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_LB
#undef LJ_CUT
#undef LJ_EWALD
*/

/* Twin-range cut-off kernels */
#define VDW_CUTOFF_CHECK
#define LJ_CUT
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_CUT
/*
#define LJ_FORCE_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_FORCE_SWITCH
#define LJ_POT_SWITCH
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_POT_SWITCH
*/
/*
#define LJ_EWALD
#define LJ_CUT
#define LJ_EWALD_COMB_GEOM
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_GEOM
#define LJ_EWALD_COMB_LB
#include "gromacs/nbnxm/kernels_reference/kernel_ref_includes.h"
#undef LJ_EWALD_COMB_LB
#undef LJ_CUT
#undef LJ_EWALD
#undef VDW_CUTOFF_CHECK
*/
#undef CALC_COUL_TAB
