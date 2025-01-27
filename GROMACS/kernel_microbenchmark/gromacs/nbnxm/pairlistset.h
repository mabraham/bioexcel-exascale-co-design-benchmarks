/*
 * This file is part of the GROMACS molecular simulation package.
 *
 * Copyright (c) 2012,2013,2014,2015,2017,2018,2019, by the GROMACS development team, led by
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

/*! \internal \file
 *
 * \brief
 * Declares the PairlistSet class
 *
 * There is one PairlistSet object per locality. A PairlistSet
 * holds a list of CPU- or GPU-type pairlist objects, one for each thread,
 * as well as helper objects to construct each of those pairlists.
 *
 * \author Berk Hess <hess@kth.se>
 * \ingroup module_nbnxm
 */

#ifndef GMX_NBNXM_PAIRLISTSET_H
#define GMX_NBNXM_PAIRLISTSET_H

#include <memory>

//#include "gromacs/math/vectypes.h"
#include "pairlist.h"
#include "gromacs/utility/basedefinitions.h"
#include "gromacs/utility/real.h"

//#include "locality.h"

struct nbnxn_atomdata_t;
struct PairlistParams;

/*! \internal
 * \brief An object that holds the local or non-local pairlists
 */
class PairlistSet
{
    public:
        //! The locality of the pairlist set
        //Nbnxm::InteractionLocality     locality_;
        int                            locality_;
        //! List of pairlists in CPU layout
        std::vector<NbnxnPairlistCpu>  cpuLists_;
        //! List of working list for rebalancing CPU lists
        //std::vector<NbnxnPairlistCpu>  cpuListsWork_;
        //! List of pairlists in GPU layout
        std::vector<NbnxnPairlistGpu>  gpuLists_;
        //! Pairlist parameters describing setup and ranges
        //const PairlistParams          &params_;
        //! Tells whether multiple lists get merged into one (the first) after creation
        bool                           combineLists_;
        //! Tells whether the lists is of CPU type, otherwise GPU type
        gmx_bool                       isCpuType_;
        //! Lists for perturbed interactions in simple atom-atom layout
        //std::vector < std::unique_ptr < t_nblist>> fepLists_;

        /* Pair counts for flop counting */
        //! Total number of atom pairs for LJ+Q kernel
        int natpair_ljq_;
        //! Total number of atom pairs for LJ kernel
        int natpair_lj_;
        //! Total number of atom pairs for Q kernel
        int natpair_q_;
};

#endif
