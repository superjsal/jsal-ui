import * as Consumables from '@features/settings/model/consumables_auto_gen';
import { ConsumesSpec, Profession, UnitReference } from '@generated/proto/common';
import { RestorationDruid_Options as RestorationDruidOptions } from '@generated/proto/druid';

export const DefaultOptions = RestorationDruidOptions.create({
	classOptions: {
		innervateTarget: UnitReference.create(),
	},
});

export const DefaultConsumables = ConsumesSpec.create({
	foodId: Consumables.SoaringPamplona.id,
	resourcePotId: Consumables.MajorManaPotion.id,
});

export const OtherDefaults = {
	distanceFromTarget: 20,
	profession1: Profession.Tailoring,
	profession2: Profession.Enchanting,
};
