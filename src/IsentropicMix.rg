-- Copyright (c) "2019, by Stanford University
--               Developer: Mario Di Renzo
--               Affiliation: Center for Turbulence Research, Stanford University
--               URL: https://ctr.stanford.edu
--               Citation: Di Renzo, M., Lin, F., and Urzay, J. (2020).
--                         HTR solver: An open-source exascale-oriented task-based
--                         multi-GPU high-order code for hypersonic aerothermodynamics.
--                         Computer Physics Communications 255, 107262"
-- All rights reserved.
-- 
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
-- 
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
-- (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
-- LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
-- ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import "regent"

return function(SCHEMA) local Exports = {}

-- Utility functions
local C = regentlib.c
local fabs = regentlib.fabs(double)
local pow  = regentlib.pow(double)
local sqrt = regentlib.sqrt(double)

-- Constants
local RGAS = 8.3144598        -- [J/(mol K)]

Exports.nSpec = 1

struct Exports.Mixture {
   -- Mixture properties
   R     : double
   gamma : double
}

__demand(__inline)
task Exports.InitMixture(config : SCHEMA.Config)
   regentlib.assert(config.Flow.mixture.type == SCHEMA.MixtureModel_IsentropicMix,
                    "This executable is expecting IsentropicMix in the input file");
   var Mix : Exports.Mixture
   Mix.R     = config.Flow.mixture.u.IsentropicMix.gasConstant
   Mix.gamma = config.Flow.mixture.u.IsentropicMix.gamma
   return Mix
end

__demand(__inline)
task Exports.GetSpeciesNames(Mix : Exports.Mixture)
   var Names : regentlib.string[Exports.nSpec]
   Names[0] = "MIX"
   return Names
end

__demand(__inline)
task Exports.FindSpecies(name : &int8, Mix : Exports.Mixture)
   return 0
end

__demand(__inline)
task Exports.CheckMixture(Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   var tmp = 0.0
   for i = 0, Exports.nSpec do
      tmp += Yi[i]
   end
   tmp -= 1.0
-- TODO: the assert is not yet supported by the cuda compiler 
--       at the moment we return something in place of the assertion
--   regentlib.assert(fabs(tmp)<1e-3, "Sum of Yi exceeded unit value");
   var err = 0
   if (fabs(tmp)>1e-3) then err = 1 end
   return err
end

__demand(__inline)
task Exports.ClipYi(Yi : double[Exports.nSpec])
   for i = 0, Exports.nSpec do
      Yi[i] max= 1.0e-60
      Yi[i] min= 1.0
   end
   return Yi
end

__demand(__inline)
task Exports.GetMolarWeightFromYi(Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return RGAS/Mix.R
end

__demand(__inline)
task Exports.GetMolarWeightFromXi(Xi : double[Exports.nSpec], Mix : Exports.Mixture)
   return RGAS/Mix.R
end

__demand(__inline)
task Exports.GetMolarFractions(MixW : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return Yi
end

__demand(__inline)
task Exports.GetMassFractions(MixW : double, Xi : double[Exports.nSpec], Mix : Exports.Mixture)
   return Xi
end

__demand(__inline)
task Exports.GetRhoFromRhoYi( rhoYi : double[Exports.nSpec] )
   var rho = rhoYi[0]
   return rho
end

__demand(__inline)
task Exports.GetYi(rho : double, rhoYi : double[Exports.nSpec])
   for i = 0, Exports.nSpec do
      rhoYi[i] /= rho
   end
   return rhoYi
end

__demand(__inline)
task Exports.GetRhoYiFromYi(rho : double, Yi : double[Exports.nSpec])
   for i = 0, Exports.nSpec do
      Yi[i] *= rho
   end
   return Yi
end

__demand(__inline)
task Exports.GetRho(P : double, T : double, MixW : double, Mix : Exports.Mixture)
   return pow(T, 1.0/(Mix.gamma-1))
end

__demand(__inline)
task Exports.GetHeatCapacity(T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return Mix.gamma/(Mix.gamma-1)*Mix.R
end

__demand(__inline)
task Exports.GetEnthalpy( T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture )
   return Mix.gamma/(Mix.gamma-1)*Mix.R*T
end

__demand(__inline)
task Exports.GetSpeciesEnthalpy(i : int, T : double,  Mix : Exports.Mixture)
   return T*Mix.R*Mix.gamma/(Mix.gamma-1.0)
end

__demand(__inline)
task Exports.GetSpeciesMolarWeight(i : int, Mix : Exports.Mixture)
   return RGAS/Mix.R
end

__demand(__inline)
task Exports.GetInternalEnergy(T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return T*Mix.R/(Mix.gamma-1.0)
end

__demand(__inline)
task Exports.GetSpecificInternalEnergy(i : int, T : double,  Mix : Exports.Mixture)
   return T*Mix.R/(Mix.gamma-1.0)
end

__demand(__inline)
task Exports.GetTFromInternalEnergy(e0 : double, T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return e0*(Mix.gamma-1.0)/Mix.R
end

__demand(__inline)
task Exports.isValidInternalEnergy(e : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return (e > 0)
end

__demand(__inline)
task Exports.GetTFromRhoAndP(rho: double, MixW : double, P : double)
   return P*MixW/(rho*RGAS)
end

__demand(__inline)
task Exports.GetPFromRhoAndT(rho: double, MixW : double, T : double)
   return rho*RGAS*T/MixW
end

__demand(__inline)
task Exports.GetViscosity(T : double, Xi : double[Exports.nSpec], Mix : Exports.Mixture)
   return 0.0
end

__demand(__inline)
task Exports.GetHeatConductivity(T : double, Xi : double[Exports.nSpec], Mix : Exports.Mixture)
   return 0.0
end

__demand(__inline)
task Exports.GetGamma(T : double, MixW : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return Mix.gamma
end

__demand(__inline)
task Exports.GetSpeedOfSound(T: double, gamma : double, MixW : double, Mix : Exports.Mixture)
   return sqrt(Mix.gamma*Mix.R*T)
end

__demand(__inline)
task Exports.GetDiffusivity(P: double, T : double, MixW : double, Xi : double[Exports.nSpec], Mix : Exports.Mixture)
   return array(0.0)
end

__demand(__inline)
task Exports.GetProductionRates(rho : double, P : double, T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return array(0.0)
end

__demand(__inline)
task Exports.Getdpde(rho : double, gamma : double, Mix : Exports.Mixture)
   return rho*(Mix.gamma - 1)
end

__demand(__inline)
task Exports.Getdpdrhoi(gamma : double, T : double, Yi : double[Exports.nSpec], Mix : Exports.Mixture)
   return array( Mix.R*T )
end

return Exports end