// ignore_for_file: library_private_types_in_public_api

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:loading_indicator/loading_indicator.dart';

class LoaderPage extends StatefulWidget {
  const LoaderPage({super.key});

  @override
  _LoaderPageState createState() => _LoaderPageState();
}

class _LoaderPageState extends State<LoaderPage> {
  late String randomFact;

  List<String> sustainabilityFacts = [
    "The sun produces more energy in one hour than the entire world consumes in a year.",
    "Wind energy is the fastest-growing renewable energy source in the world.",
    "A single wind turbine can power over 1,500 homes annually.",
    "Hydropower is the largest source of renewable electricity worldwide.",
    "Geothermal energy uses the Earth's heat to generate power and can operate 24/7.",
    "Solar panels can still generate electricity on cloudy days.",
    "The first solar cell was created in 1954 by Bell Labs.",
    "Wave and tidal energy could produce 10% of the world’s electricity needs.",
    "One acre of solar panels can generate up to 400 times more energy than an acre of corn for biofuel.",
    "Renewable energy jobs are growing faster than fossil fuel jobs.",
    "Electric cars can convert over 60% of their energy into motion, compared to only 20% for gas cars.",
    "Recycling one aluminum can saves enough energy to power a TV for three hours.",
    "Turning off lights when not in use can save up to 15% on your electricity bill.",
    "LED bulbs use 75% less energy than incandescent bulbs and last 25 times longer.",
    "The average home loses 25%–30% of its heat through windows.",
    "Biodegradable plastics still take years to break down in landfills without proper conditions.",
    "Composting can reduce household waste by up to 30%.",
    "It takes 700 gallons of water to make one cotton T-shirt.",
    "Plastic pollution kills over 1 million marine animals each year.",
    "Using a reusable water bottle can save 167 plastic bottles per person annually.",
    "Bamboo grows 30 times faster than regular trees and absorbs more CO₂.",
    "Solar farms can be built on rooftops, deserts, and even floating on water.",
    "Hydrogen fuel cells generate electricity with only water vapor as a byproduct.",
    "The world’s first fully solar-powered airport is in India (Cochin International Airport).",
    "Electric buses can save up to 80,000 pounds of CO₂ emissions per year compared to diesel buses.",
    "One mature tree can absorb up to 48 pounds of CO₂ per year.",
    "If food waste were a country, it would be the third-largest emitter of greenhouse gases.",
    "Producing 1 pound of beef requires 1,800 gallons of water.",
    "Growing urban green spaces can reduce city temperatures by up to 5°F.",
    "Algae-based biofuel can produce up to 100 times more oil per acre than traditional biofuels.",
    "Some solar panels have a lifespan of 40 years or more.",
    "Nuclear power is a low-carbon energy source but produces radioactive waste.",
    "Microgrids can provide energy to remote communities without reliance on large power plants.",
    "Ocean thermal energy uses temperature differences in seawater to generate power.",
    "Using public transport instead of driving can reduce carbon footprints by 45%.",
    "One hour of bike riding instead of driving prevents about 1 pound of CO₂ emissions.",
    "Rainwater harvesting can reduce household water use by 30%.",
    "Drought-resistant plants in landscaping can cut outdoor water use by 50%.",
    "Using cold water for laundry can save up to 90% of washing machine energy.",
    "Energy-efficient buildings can reduce energy use by 50% or more.",
    "Installing a programmable thermostat can cut heating and cooling costs by 10-30%.",
    "Earthships are homes made from recycled materials and run on renewable energy.",
    "Reclaimed wood reduces the demand for deforestation and is highly sustainable.",
    "Eco-friendly concrete can absorb CO₂, making buildings more sustainable.",
    "The Great Pacific Garbage Patch is twice the size of Texas.",
    "Plastic straws take 200 years to decompose.",
    "A single cow produces up to 220 pounds of methane annually.",
    "Replacing a gas-powered lawn mower with an electric one reduces pollution significantly.",
    "By 2050, there could be more plastic in the ocean than fish (by weight).",
    "Eating one plant-based meal per week reduces carbon footprints significantly.",
  ];

  @override
  void initState() {
    super.initState();
    randomFact =
        sustainabilityFacts[Random().nextInt(sustainabilityFacts.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loader Animation
            SizedBox(
              height: 50,
              width: 50,
              child: LoadingIndicator(
                indicatorType: Indicator.ballScaleMultiple,
                colors: [Theme.of(context).colorScheme.onPrimary],
                strokeWidth: 2,
              ),
            ),
            SizedBox(height: 20),

            // Displaying Random Sustainability Fact
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                randomFact,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
